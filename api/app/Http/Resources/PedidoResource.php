<?php

namespace App\Http\Resources;

use App\Models\Pedido;
use App\Models\Resena;
use App\Support\Archivos;
use App\Support\CobroQr;
use App\Support\FlujoPedido;
use App\Support\RepartidoresCerca;
use App\Support\VencimientoPedidos;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Pedido para la app. Lo pueden ver el comprador, el dueño del negocio y el
 * repartidor que lo lleva, y cada uno recibe solo lo que le corresponde:
 * - comprador: el PIN de entrega y sus reseñas (cuando ya lo recibió);
 * - negocio y repartidor: nombre y teléfono del cliente (nunca el PIN).
 * `acciones` = estados a los que puede pasarlo quien pregunta.
 *
 * @mixin Pedido
 */
class PedidoResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $usuarioId = (int) $request->user()?->id;
        $esComprador = (int) $this->comprador_id === $usuarioId;
        $rol = match (true) {
            $esComprador => 'cliente',
            $this->repartidor_id !== null && (int) $this->repartidor_id === $usuarioId => 'repartidor',
            default => 'comerciante',
        };
        $detalle = $this->relationLoaded('items');

        return [
            'id' => $this->id,
            'estado' => $this->estado,
            'negocio' => $this->whenLoaded('negocio', fn () => [
                'id' => $this->negocio->id,
                'nombre' => $this->negocio->nombre,
                'logo_url' => Archivos::url($this->negocio->logo_url),
                'telefono' => $this->negocio->telefono,
                'direccion' => $this->negocio->direccion,
                'latitud' => $this->negocio->latitud,
                'longitud' => $this->negocio->longitud,
            ]),
            'cliente' => $this->when(! $esComprador && $this->relationLoaded('comprador'), fn () => [
                'nombre' => $this->comprador->nombre_completo,
                'telefono' => $this->comprador->telefono,
            ]),
            // Quién lo lleva (lo ven el cliente, el negocio y el propio repartidor).
            'repartidor' => $this->whenLoaded('repartidor', fn () => $this->repartidor ? [
                'nombre' => $this->repartidor->nombre_completo,
                'telefono' => $this->repartidor->telefono,
                'vehiculo' => $this->vehiculo?->tipo?->nombre,
                'placa' => $this->vehiculo?->placa,
                'color' => $this->vehiculo?->color,
            ] : null),
            // Al negocio, mientras espera repartidor: "Buscando repartidor… 3 cerca de tu tienda".
            'repartidores_cerca' => $this->when(
                $rol === 'comerciante' && $this->estado === 'listo' && $this->repartidor_id === null && $this->relationLoaded('negocio'),
                fn () => RepartidoresCerca::contar($this->resource)
            ),
            // Al negocio, en un pedido nuevo: hasta cuándo puede aceptarlo (cuenta regresiva).
            'aceptar_antes' => $this->when($rol === 'comerciante' && $this->estado === 'pendiente',
                fn () => VencimientoPedidos::aceptarAntes($this->resource)),
            // Tamaño de vehículo que necesita: Liviano, Mediano o Grande.
            'tamano' => $this->whenLoaded('categoriaVehiculo', fn () => $this->categoriaVehiculo?->nombre),
            'direccion_entrega' => $this->direccion_entrega,
            'referencia_entrega' => $this->referencia_entrega,
            'latitud_entrega' => $this->latitud_entrega,
            'longitud_entrega' => $this->longitud_entrega,
            'notas' => $this->notas,
            'subtotal' => $this->subtotal,
            'costo_envio' => $this->costo_envio,
            'tarifa_servicio' => $this->tarifa_servicio,
            'descuento' => $this->descuento,
            'total' => $this->total,
            'metodo_pago' => $this->metodo_pago,
            // Efectivo: con cuánto paga y cuánto cambio le dan (lo ven el cliente, el negocio y el repartidor).
            'paga_con' => $this->paga_con,
            'cambio' => $this->paga_con !== null ? number_format((float) $this->paga_con - (float) $this->total, 2, '.', '') : null,
            // Lo que se ahorró con las ofertas (precio sin oferta − precio cobrado).
            'ahorro' => $this->when($detalle, fn () => number_format($this->items->sum(
                fn ($i) => $i->precio_original !== null ? max(0, ((float) $i->precio_original - (float) $i->precio_unitario) * $i->cantidad) : 0
            ), 2, '.', '')),
            'estado_pago' => $this->estado_pago,
            // Cobro con QR (simulado): solo el comprador recibe el contenido del QR para pagarlo.
            'pago_qr' => $this->when($esComprador && $this->metodo_pago === 'qr' && $this->referencia_pago !== null, fn () => [
                'referencia' => $this->referencia_pago,
                'contenido' => CobroQr::contenido($this->resource),
            ]),
            // El PIN lo da el cliente al recibir: solo lo ve él.
            'codigo_entrega' => $this->when($esComprador, $this->codigo_entrega),
            'distancia_km' => $this->distancia_km,
            'motivo_cancelacion' => $this->motivo_cancelacion,
            'total_items' => $this->whenCounted('items'),
            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($item) => [
                'id' => $item->id,
                'producto_id' => $item->producto_id,
                'nombre' => $item->producto_nombre,
                'imagen_url' => Archivos::url($item->producto?->imagenPrincipal?->url),
                'precio_unitario' => $item->precio_unitario,
                'precio_original' => $item->precio_original,
                'cantidad' => $item->cantidad,
                'subtotal' => $item->subtotal,
                'notas' => $item->notas,
                'alistado' => (bool) $item->alistado,
            ])),
            'historial' => $this->whenLoaded('historial', fn () => $this->historial->map(fn ($h) => [
                'estado' => $h->estado_nuevo,
                'motivo' => $h->motivo,
                'fecha' => $h->created_at,
            ])),
            'acciones' => $this->when($detalle, fn () => FlujoPedido::siguientes($this->resource, $rol)),
            'mis_resenas' => $this->when($detalle && $esComprador && $this->estado === 'entregado',
                fn () => $this->misResenas($usuarioId)),
            'created_at' => $this->created_at,
            'confirmado_en' => $this->confirmado_en,
            'recogido_en' => $this->recogido_en,
            'entregado_en' => $this->entregado_en,
            'cancelado_en' => $this->cancelado_en,
        ];
    }

    /** Lo que el comprador ya calificó de este pedido (para mostrar sus estrellas). */
    private function misResenas(int $usuarioId): array
    {
        $resenas = Resena::where('autor_id', $usuarioId)
            ->where(fn ($q) => $q
                ->where(fn ($q) => $q->where('tipo', 'negocio')->where('negocio_id', $this->negocio_id))
                ->orWhere(fn ($q) => $q->where('tipo', 'repartidor')->where('repartidor_id', $this->repartidor_id))
                ->orWhere(fn ($q) => $q->where('tipo', 'producto')->whereIn('producto_id', $this->items->pluck('producto_id'))))
            ->get();

        $formato = fn (Resena $r) => [
            'id' => $r->id,
            'producto_id' => $r->producto_id,
            'estrellas' => $r->estrellas,
            'comentario' => $r->comentario,
            'etiquetas' => $r->etiquetas ?? [],
        ];
        $negocio = $resenas->firstWhere('tipo', 'negocio');
        $repartidor = $this->repartidor_id !== null ? $resenas->firstWhere('tipo', 'repartidor') : null;

        return [
            'negocio' => $negocio ? $formato($negocio) : null,
            // A quién calificar: el repartidor que lo entregó (null si no hubo).
            'repartidor_id' => $this->repartidor_id,
            'repartidor' => $repartidor ? $formato($repartidor) : null,
            // Lista (no mapa): Laravel renumera los arreglos con claves numéricas.
            'productos' => $resenas->where('tipo', 'producto')->map($formato)->values()->all(),
        ];
    }
}
