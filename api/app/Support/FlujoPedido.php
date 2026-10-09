<?php

namespace App\Support;

use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\Usuario;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Cambios de estado de un pedido: quién puede hacer cada uno, qué fechas se
 * guardan y el historial. Lo usan la API (cliente y comerciante) y el panel.
 *
 *   pendiente → confirmado → preparando → listo → en_camino → entregado
 *   (cancelado o rechazado antes de salir)
 *
 * Mientras no exista el módulo del repartidor, el negocio entrega con su
 * propio delivery: pasa el pedido a "en_camino" y lo entrega pidiendo el PIN.
 * Al entregar, la base (trg_pedido_au) registra la venta; al cancelar o
 * rechazar, devuelve el stock.
 */
class FlujoPedido
{
    /** Qué estados puede poner cada rol, según el estado actual. */
    private const PERMITIDOS = [
        'cliente' => [
            'pendiente' => ['cancelado'],
        ],
        'comerciante' => [
            'pendiente' => ['confirmado', 'rechazado'],
            'confirmado' => ['preparando', 'cancelado'],
            'preparando' => ['listo', 'cancelado'],
            'listo' => ['en_camino', 'cancelado'],
            'en_camino' => ['entregado'],
        ],
        'admin' => [
            'pendiente' => ['cancelado'],
            'confirmado' => ['cancelado'],
            'preparando' => ['cancelado'],
            'listo' => ['cancelado'],
            'en_camino' => ['cancelado'],
        ],
    ];

    /** Siguientes estados posibles para ese rol (para mostrar los botones). */
    public static function siguientes(Pedido $pedido, string $rol): array
    {
        return self::PERMITIDOS[$rol][$pedido->estado] ?? [];
    }

    public static function cambiar(Pedido $pedido, string $nuevo, Usuario $quien, string $rol, ?string $motivo = null): Pedido
    {
        return DB::transaction(function () use ($pedido, $nuevo, $quien, $rol, $motivo) {
            // Se vuelve a leer bloqueado: si dos personas tocan el pedido a la vez, gana la primera.
            $pedido = Pedido::lockForUpdate()->findOrFail($pedido->id);
            $anterior = $pedido->estado;

            if (! in_array($nuevo, self::siguientes($pedido, $rol), true)) {
                throw ValidationException::withMessages([
                    'estado' => 'El pedido ya está "'.self::texto($anterior).'" y no se puede cambiar a "'.self::texto($nuevo).'".',
                ]);
            }

            $cambios = ['estado' => $nuevo];
            match ($nuevo) {
                'confirmado' => $cambios['confirmado_en'] = now(),
                'en_camino' => $cambios['recogido_en'] = now(),
                'entregado' => $cambios += [
                    'entregado_en' => now(),
                    // En efectivo se paga al recibir.
                    'estado_pago' => 'pagado',
                    'pagado_en' => $pedido->pagado_en ?? now(),
                ],
                'cancelado', 'rechazado' => $cambios += [
                    'cancelado_en' => now(),
                    'cancelado_por' => $quien->id,
                    'motivo_cancelacion' => $motivo,
                ],
                default => null,
            };
            $pedido->forceFill($cambios)->save();
            $pedido->registrarEstado($anterior, $nuevo, $quien->id, $rol, $motivo);

            self::avisar($pedido, $nuevo, $rol);

            return $pedido->refresh();
        });
    }

    public static function texto(string $estado): string
    {
        return [
            'pendiente' => 'esperando al negocio',
            'confirmado' => 'aceptado',
            'preparando' => 'en preparación',
            'listo' => 'listo',
            'en_camino' => 'en camino',
            'entregado' => 'entregado',
            'cancelado' => 'cancelado',
            'rechazado' => 'rechazado',
        ][$estado] ?? $estado;
    }

    /** Avisa al comprador (o al negocio, si canceló el comprador). */
    private static function avisar(Pedido $pedido, string $nuevo, string $rol): void
    {
        if ($rol === 'cliente') {
            Notificacion::avisar($pedido->negocio->usuario_id, 'pedido_cancelado',
                "El pedido #{$pedido->id} fue cancelado por el cliente", null, $pedido->id);

            return;
        }

        $titulos = [
            'confirmado' => 'El negocio aceptó tu pedido',
            'preparando' => 'Están preparando tu pedido',
            'listo' => 'Tu pedido está listo',
            'en_camino' => 'Tu pedido va en camino',
            'entregado' => 'Pedido entregado. ¡Califícalo!',
            'cancelado' => 'Tu pedido fue cancelado',
            'rechazado' => 'El negocio no pudo aceptar tu pedido',
        ];
        Notificacion::avisar($pedido->comprador_id, 'pedido_'.$nuevo,
            $titulos[$nuevo] ?? 'Tu pedido cambió de estado', $pedido->motivo_cancelacion, $pedido->id);
    }
}
