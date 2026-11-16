<?php

namespace App\Support;

use App\Models\Configuracion;
use App\Models\Pedido;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

/**
 * Pedidos que nadie atendió a tiempo. Lo corre la tarea automática
 * `php artisan pedidos:vencer` (ver routes/console.php):
 *
 * - Pedido nuevo que la tienda no aceptó ni rechazó en `minutos_para_aceptar`
 *   → se rechaza solo. Con QR, el plazo corre desde que el cliente pagó (antes
 *   la tienda no puede aceptarlo).
 * - Pedido con QR que el cliente no pagó en `minutos_para_pagar_qr` → se
 *   cancela solo (libera el stock que tenía reservado).
 * - Pedido "listo" que ningún repartidor tomó en `minutos_listo_sin_repartidor`
 *   → se cancela solo. El plazo corre desde que quedó libre (al marcarlo
 *   listo, o desde que un repartidor lo soltó).
 *
 * Los plazos están en la tabla `configuracion` (se cambian sin tocar código,
 * también desde el panel /admin). Como en cualquier cancelación, la base
 * devuelve el stock y FlujoPedido reembolsa el QR y avisa al cliente y al negocio.
 */
class VencimientoPedidos
{
    public const MOTIVO_SIN_RESPUESTA = 'La tienda no respondió a tiempo';

    public const MOTIVO_SIN_PAGO = 'No se pagó con QR a tiempo';

    public const MOTIVO_SIN_REPARTIDOR = 'Ningún repartidor pudo tomar el pedido a tiempo';

    /** Si faltan en `configuracion`, se usan estos. */
    public const MINUTOS_PARA_ACEPTAR = 1;

    public const MINUTOS_PARA_PAGAR_QR = 10;

    public const MINUTOS_LISTO_SIN_REPARTIDOR = 30;

    /** Pedidos que se revisan por vez (los que queden, en la siguiente pasada). */
    private const POR_PASADA = 200;

    /** @return array{rechazados: int, sin_pago: int, cancelados: int} */
    public static function ejecutar(): array
    {
        return [
            'rechazados' => self::resolver(self::sinRespuesta(), 'rechazado', self::MOTIVO_SIN_RESPUESTA),
            'sin_pago' => self::resolver(self::sinPago(), 'cancelado', self::MOTIVO_SIN_PAGO),
            'cancelados' => self::resolver(self::sinRepartidor(), 'cancelado', self::MOTIVO_SIN_REPARTIDOR),
        ];
    }

    /** Pedidos con QR que el cliente no pagó dentro del plazo. */
    public static function sinPago(): Builder
    {
        $limite = now()->subSeconds(self::minutos('minutos_para_pagar_qr', self::MINUTOS_PARA_PAGAR_QR) * 60);

        return Pedido::query()
            ->where('estado', 'pendiente')
            ->where('metodo_pago', 'qr')
            ->where('estado_pago', '!=', 'pagado')
            ->where('created_at', '<=', $limite);
    }

    /** Pedidos nuevos cuyo plazo para aceptar ya pasó. */
    public static function sinRespuesta(): Builder
    {
        $limite = now()->subSeconds(self::minutos('minutos_para_aceptar', self::MINUTOS_PARA_ACEPTAR) * 60);

        return Pedido::query()
            ->where('estado', 'pendiente')
            ->where(fn ($q) => $q
                ->where(fn ($q) => $q->where('metodo_pago', '!=', 'qr')->where('created_at', '<=', $limite))
                // Con QR sin pagar todavía no corre el plazo: la tienda no puede aceptarlo.
                ->orWhere(fn ($q) => $q->where('metodo_pago', 'qr')->where('estado_pago', 'pagado')->where('pagado_en', '<=', $limite)));
    }

    /** Pedidos listos, sin repartidor, libres desde hace más del plazo. */
    public static function sinRepartidor(): Builder
    {
        $limite = now()->subSeconds(self::minutos('minutos_listo_sin_repartidor', self::MINUTOS_LISTO_SIN_REPARTIDOR) * 60);

        // "Libre desde" = último registro del historial que lo dejó en "listo"
        // (al marcarlo listo o cuando un repartidor lo soltó).
        return Pedido::query()
            ->where('estado', 'listo')
            ->whereNull('repartidor_id')
            ->whereRaw(
                '(SELECT MAX(h.created_at) FROM pedido_estado_historial h WHERE h.pedido_id = pedido.id AND h.estado_nuevo = ?) <= ?',
                ['listo', $limite->format('Y-m-d H:i:s')]
            );
    }

    private static function resolver(Builder $consulta, string $nuevo, string $motivo): int
    {
        $hechos = 0;
        foreach ($consulta->orderBy('id')->limit(self::POR_PASADA)->get() as $pedido) {
            try {
                FlujoPedido::cambiar($pedido, $nuevo, null, 'sistema', $motivo);
                $hechos++;
            } catch (ValidationException) {
                // Justo lo atendieron (lo aceptó la tienda o lo tomó un repartidor): se deja.
            } catch (\Throwable $e) {
                // Uno con problemas no frena a los demás; queda en el registro del servidor.
                Log::error("No se pudo vencer el pedido #{$pedido->id}: {$e->getMessage()}");
            }
        }

        return $hechos;
    }

    private static function minutos(string $clave, float $defecto): float
    {
        return max(0, (float) Configuracion::valor($clave, $defecto));
    }
}
