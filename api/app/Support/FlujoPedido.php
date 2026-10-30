<?php

namespace App\Support;

use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\Repartidor;
use App\Models\Usuario;
use App\Models\Vehiculo;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Cambios de estado de un pedido: quién puede hacer cada uno, qué fechas se
 * guardan y el historial. Lo usan la API (cliente y comerciante) y el panel.
 *
 *   pendiente → confirmado → preparando → listo → en_camino → entregado
 *   (cancelado o rechazado antes de salir)
 *
 * El negocio lo lleva hasta "listo". Todo pedido lo entrega un repartidor de
 * la app (el local no tiene delivery propio): lo acepta (aceptar), lo pasa a
 * "en_camino" (lo recogió) y a "entregado" (con el PIN). Antes de recogerlo
 * puede soltarlo y vuelve a quedar disponible. Mientras nadie lo tome, el
 * negocio puede cancelarlo.
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
            // Nunca "en_camino" ni "entregado": eso lo hace el repartidor.
            'listo' => ['cancelado'],
        ],
        'repartidor' => [
            'listo' => ['en_camino'],
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
        $siguientes = self::PERMITIDOS[$rol][$pedido->estado] ?? [];

        return match (true) {
            // Ya lo tomó un repartidor (va a buscarlo): el negocio ya no lo puede cancelar.
            $rol === 'comerciante' && $pedido->repartidor_id !== null => [],
            // El repartidor solo mueve los pedidos que aceptó.
            $rol === 'repartidor' && $pedido->repartidor_id === null => [],
            default => $siguientes,
        };
    }

    public static function cambiar(Pedido $pedido, string $nuevo, Usuario $quien, string $rol, ?string $motivo = null): Pedido
    {
        return DB::transaction(function () use ($pedido, $nuevo, $quien, $rol, $motivo) {
            // Se vuelve a leer bloqueado: si dos personas tocan el pedido a la vez, gana la primera.
            $pedido = Pedido::lockForUpdate()->findOrFail($pedido->id);
            $anterior = $pedido->estado;

            // Pudo soltarlo (o tomarlo otro) justo antes: solo lo mueve quien lo lleva.
            if ($rol === 'repartidor' && (int) $pedido->repartidor_id !== (int) $quien->id) {
                throw ValidationException::withMessages(['estado' => 'Este pedido ya no está a tu cargo.']);
            }

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

    /**
     * El repartidor acepta un pedido "listo" y sin repartidor. Se bloquean el
     * repartidor (un solo pedido a la vez, aunque toque dos veces) y el pedido
     * (si dos repartidores aceptan a la vez, gana el primero).
     */
    public static function aceptar(Pedido $pedido, Repartidor $repartidor, Vehiculo $vehiculo): Pedido
    {
        return DB::transaction(function () use ($pedido, $repartidor, $vehiculo) {
            Repartidor::lockForUpdate()->findOrFail($repartidor->usuario_id);
            $pedido = Pedido::with(['negocio', 'categoriaVehiculo'])->lockForUpdate()->findOrFail($pedido->id);

            $error = match (true) {
                $repartidor->pedidos()->whereIn('estado', Pedido::ESTADOS_REPARTO)->exists() => 'Ya tienes un pedido en curso. Entrégalo antes de aceptar otro.',
                $pedido->repartidor_id !== null => 'Otro repartidor ya aceptó este pedido.',
                $pedido->estado !== 'listo' => 'Este pedido ya no está disponible.',
                in_array((int) $repartidor->usuario_id, [(int) $pedido->comprador_id, (int) $pedido->negocio->usuario_id], true) => 'No puedes llevar un pedido tuyo o de tu negocio.',
                ($pedido->categoriaVehiculo?->nivel ?? 1) > $vehiculo->tipo->categoria->nivel => 'Este pedido necesita un vehículo más grande.',
                default => null,
            };
            if ($error) {
                throw ValidationException::withMessages(['pedido' => $error]);
            }

            $pedido->forceFill(['repartidor_id' => $repartidor->usuario_id, 'vehiculo_id' => $vehiculo->id, 'asignado_en' => now()])->save();
            $pedido->registrarEstado('listo', 'listo', $repartidor->usuario_id, 'repartidor', 'Lo aceptó un repartidor');

            Notificacion::avisar($pedido->comprador_id, 'pedido_asignado', 'Un repartidor llevará tu pedido', null, $pedido->id);
            Notificacion::avisar($pedido->negocio->usuario_id, 'pedido_asignado',
                "Un repartidor aceptó el pedido #{$pedido->id}", 'Pasará a recogerlo.', $pedido->id);

            return $pedido->refresh();
        });
    }

    /** Antes de recogerlo, el repartidor lo suelta: vuelve a quedar disponible. */
    public static function soltar(Pedido $pedido, Usuario $quien, ?string $motivo = null): Pedido
    {
        return DB::transaction(function () use ($pedido, $quien, $motivo) {
            $pedido = Pedido::with('negocio')->lockForUpdate()->findOrFail($pedido->id);
            if ((int) $pedido->repartidor_id !== (int) $quien->id) {
                throw ValidationException::withMessages(['pedido' => 'Este pedido ya no está a tu cargo.']);
            }
            if ($pedido->estado !== 'listo') {
                throw ValidationException::withMessages(['pedido' => 'Ya lo recogiste: ahora tienes que entregarlo.']);
            }

            $pedido->forceFill(['repartidor_id' => null, 'vehiculo_id' => null, 'asignado_en' => null])->save();
            $pedido->registrarEstado('listo', 'listo', $quien->id, 'repartidor', $motivo ?: 'El repartidor soltó el pedido');
            Notificacion::avisar($pedido->negocio->usuario_id, 'pedido_liberado',
                "El repartidor soltó el pedido #{$pedido->id}", 'Vuelve a estar disponible para otro repartidor.', $pedido->id);

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

        // Lo recogió o lo entregó el repartidor: también se entera el negocio.
        if ($rol === 'repartidor') {
            Notificacion::avisar($pedido->negocio->usuario_id, 'pedido_'.$nuevo,
                $nuevo === 'entregado' ? "El pedido #{$pedido->id} fue entregado" : "El repartidor recogió el pedido #{$pedido->id}",
                null, $pedido->id);
        }
        // Lo cancelaron cuando ya lo llevaba un repartidor: que no vaya a buscarlo.
        if ($nuevo === 'cancelado' && $pedido->repartidor_id !== null) {
            Notificacion::avisar($pedido->repartidor_id, 'pedido_cancelado',
                "El pedido #{$pedido->id} fue cancelado", $pedido->motivo_cancelacion, $pedido->id);
        }
    }
}
