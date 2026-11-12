<?php

namespace App\Support;

use App\Models\Notificacion;
use App\Models\Pedido;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Cobro con QR SIMULADO: no mueve dinero real, pero sigue los mismos pasos
 * que un cobro de verdad.
 *
 * 1. Al pedir con QR se genera una referencia única (va dentro del QR).
 * 2. El QR lleva a /pago-qr/{referencia}, la "pasarela" de prueba: quien lo
 *    escanea confirma el pago. La app también puede confirmarlo con
 *    POST /api/pedidos/{id}/pago-qr ("Simular pago").
 * 3. procesar() marca el pedido como pagado y avisa "Cobro realizado" al
 *    cliente y al negocio. Recién entonces el negocio puede aceptarlo.
 * 4. Si después se cancela o rechaza, el pago queda "reembolsado" (ver FlujoPedido).
 */
class CobroQr
{
    /** Referencia del cobro: imposible de adivinar (la URL del QR no necesita sesión). */
    public static function nuevaReferencia(): string
    {
        return 'QR-'.Str::random(32);
    }

    public static function referenciaValida(string $referencia): bool
    {
        return (bool) preg_match('/^QR-[A-Za-z0-9]{32}$/', $referencia);
    }

    /** Lo que va dentro del QR: la página de la pasarela de prueba. */
    public static function contenido(Pedido $pedido): string
    {
        return url('/pago-qr/'.$pedido->referencia_pago);
    }

    /** ¿El negocio tiene que esperar el pago antes de aceptar el pedido? */
    public static function esperandoPago(Pedido $pedido): bool
    {
        return $pedido->metodo_pago === 'qr' && $pedido->estado_pago !== 'pagado';
    }

    /**
     * Procesa el cobro. Si ya estaba pagado no hace nada (se puede llamar dos
     * veces sin cobrar doble). 422 si el pedido no es con QR o ya se canceló.
     */
    public static function procesar(Pedido $pedido): Pedido
    {
        return DB::transaction(function () use ($pedido) {
            // Bloqueado: si llegan dos confirmaciones a la vez, se cobra una sola.
            $pedido = Pedido::lockForUpdate()->findOrFail($pedido->id);

            if ($pedido->metodo_pago !== 'qr') {
                throw ValidationException::withMessages(['pago' => 'Este pedido no se paga con QR.']);
            }
            if ($pedido->estado_pago === 'pagado') {
                return $pedido;
            }
            if (in_array($pedido->estado, ['cancelado', 'rechazado'], true)) {
                throw ValidationException::withMessages(['pago' => 'Este pedido ya fue cancelado: no se puede pagar.']);
            }

            $pedido->forceFill(['estado_pago' => 'pagado', 'pagado_en' => now()])->save();

            $monto = 'Bs '.number_format((float) $pedido->total, 2);
            Notificacion::avisar($pedido->comprador_id, 'pago_realizado', 'Cobro realizado',
                "Pagaste $monto con QR por el pedido #{$pedido->id}.", $pedido->id);
            Notificacion::avisar($pedido->negocio->usuario_id, 'pago_recibido', "Pedido #{$pedido->id} pagado con QR",
                "Recibiste $monto. Ya puedes aceptarlo.", $pedido->id);

            return $pedido->refresh();
        });
    }
}
