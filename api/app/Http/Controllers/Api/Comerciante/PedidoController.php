<?php

namespace App\Http\Controllers\Api\Comerciante;

use App\Http\Controllers\Controller;
use App\Http\Resources\PedidoResource;
use App\Models\Negocio;
use App\Models\Pedido;
use App\Support\FlujoPedido;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/** Pedidos que recibe el negocio: /api/negocios/{negocio}/pedidos (solo el dueño). */
class PedidoController extends Controller
{
    private const GRUPOS = [
        'nuevos' => ['pendiente'],
        'en_curso' => ['confirmado', 'preparando', 'listo', 'en_camino'],
        'terminados' => ['entregado', 'cancelado', 'rechazado'],
    ];

    /** GET ?grupo=nuevos|en_curso|terminados — los nuevos, del más viejo al más nuevo (orden de atención). */
    public function index(Request $request, Negocio $negocio): AnonymousResourceCollection
    {
        $grupo = $request->validate(['grupo' => ['nullable', Rule::in(array_keys(self::GRUPOS))]])['grupo'] ?? 'nuevos';

        $pedidos = $negocio->pedidos()
            ->whereIn('estado', self::GRUPOS[$grupo])
            ->with(['negocio', 'comprador'])
            ->withCount('items')
            ->when($grupo === 'terminados', fn ($q) => $q->latest('id'), fn ($q) => $q->oldest('id'))
            ->paginate(30);

        return PedidoResource::collection($pedidos);
    }

    /** GET /{pedido} — detalle con productos, cliente e historial. */
    public function show(Negocio $negocio, Pedido $pedido): PedidoResource
    {
        return new PedidoResource($this->conDetalle($pedido));
    }

    /**
     * PUT /{pedido}/estado — aceptar, rechazar, preparando, listo o cancelar.
     * "En camino" y "entregado" los hace el repartidor de la app (el local no
     * tiene delivery propio).
     */
    public function estado(Request $request, Negocio $negocio, Pedido $pedido): PedidoResource
    {
        $datos = $request->validate([
            'estado' => ['required', Rule::in(['confirmado', 'rechazado', 'preparando', 'listo', 'en_camino', 'entregado', 'cancelado'])],
            'motivo' => ['nullable', 'required_if:estado,rechazado,cancelado', 'string', 'max:255'],
        ], [
            'motivo.required_if' => 'Cuéntale al cliente por qué (ej. "nos quedamos sin stock").',
        ]);

        if (in_array($datos['estado'], ['en_camino', 'entregado'], true)) {
            throw ValidationException::withMessages(['estado' => 'Solo el repartidor de la app recoge y entrega el pedido.']);
        }

        $pedido = FlujoPedido::cambiar($pedido, $datos['estado'], $request->user(), 'comerciante', $datos['motivo'] ?? null);

        return new PedidoResource($this->conDetalle($pedido));
    }

    private function conDetalle(Pedido $pedido): Pedido
    {
        return $pedido->refresh()->load(['negocio', 'comprador', 'items.producto.imagenPrincipal', 'historial', 'repartidor', 'vehiculo.tipo']);
    }
}
