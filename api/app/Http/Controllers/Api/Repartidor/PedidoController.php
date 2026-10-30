<?php

namespace App\Http\Controllers\Api\Repartidor;

use App\Http\Controllers\Controller;
use App\Http\Resources\PedidoResource;
use App\Models\Pedido;
use App\Models\Repartidor;
use App\Models\Vehiculo;
use App\Support\Archivos;
use App\Support\FlujoPedido;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Lo que hace el repartidor: ponerse en línea, ver los pedidos "listos" que
 * puede llevar, aceptar uno, recogerlo, entregarlo con el PIN y su historial.
 * Para ver y aceptar pedidos tiene que estar aprobado, sin sanción, con su
 * vehículo aprobado y en línea.
 */
class PedidoController extends Controller
{
    /** PUT /api/repartidor/disponible — en línea o desconectado, con su ubicación (opcional). */
    public function disponible(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'disponible' => ['required', 'boolean'],
            'latitud' => ['nullable', 'required_with:longitud', 'numeric', 'between:-90,90'],
            'longitud' => ['nullable', 'required_with:latitud', 'numeric', 'between:-180,180'],
        ]);

        // Desconectarse siempre se puede; conectarse, solo si puede repartir.
        $repartidor = $datos['disponible'] ? $this->habilitado($request)[0] : $this->perfil($request);

        $cambios = ['disponible' => $datos['disponible']];
        if (isset($datos['latitud'])) {
            $cambios += [
                'latitud_actual' => $datos['latitud'],
                'longitud_actual' => $datos['longitud'],
                'ubicacion_actualizada_en' => now(),
            ];
        }
        $repartidor->forceFill($cambios)->save();

        return response()->json([
            'disponible' => (bool) $repartidor->disponible,
            'latitud' => $repartidor->latitud_actual,
            'longitud' => $repartidor->longitud_actual,
        ]);
    }

    /**
     * GET /api/repartidor/pedidos-disponibles — pedidos "listos" sin repartidor
     * que su vehículo puede llevar (de su tamaño o más chicos). Si mandó su
     * ubicación, del negocio más cercano al más lejano; si no, los que esperan
     * hace más tiempo primero. No incluye datos del cliente hasta aceptarlo.
     */
    public function disponibles(Request $request): JsonResponse
    {
        [$repartidor, $vehiculo] = $this->habilitado($request, enLinea: true);
        $nivel = $vehiculo->tipo->categoria->nivel;
        $yo = $repartidor->usuario_id;
        $conGps = $repartidor->latitud_actual !== null;

        $pedidos = Pedido::query()
            ->select('pedido.*')
            ->where('estado', 'listo')
            ->whereNull('repartidor_id')
            ->where('comprador_id', '<>', $yo)
            ->whereHas('negocio', fn ($q) => $q->where('usuario_id', '<>', $yo))
            ->where(fn ($q) => $q
                ->whereNull('categoria_vehiculo_requerida_id')
                ->orWhereHas('categoriaVehiculo', fn ($c) => $c->where('nivel', '<=', $nivel)))
            ->when($conGps,
                fn ($q) => $q
                    ->selectRaw('(SELECT fn_distancia_km(?, ?, n.latitud, n.longitud) FROM negocio n WHERE n.id = pedido.negocio_id) AS distancia_al_negocio_km',
                        [$repartidor->latitud_actual, $repartidor->longitud_actual])
                    ->orderBy('distancia_al_negocio_km'),
                fn ($q) => $q->oldest('id'))
            ->with(['negocio', 'categoriaVehiculo'])
            ->withCount('items')
            ->limit(50)
            ->get();

        return response()->json($pedidos->map(fn (Pedido $p) => [
            'id' => $p->id,
            'negocio' => [
                'id' => $p->negocio->id,
                'nombre' => $p->negocio->nombre,
                'logo_url' => Archivos::url($p->negocio->logo_url),
                'direccion' => $p->negocio->direccion,
                'latitud' => $p->negocio->latitud,
                'longitud' => $p->negocio->longitud,
            ],
            'direccion_entrega' => $p->direccion_entrega,
            'referencia_entrega' => $p->referencia_entrega,
            // Del negocio a la casa del cliente.
            'distancia_km' => $p->distancia_km,
            // De donde está el repartidor al negocio (null sin GPS).
            'distancia_al_negocio_km' => isset($p->distancia_al_negocio_km) ? (float) $p->distancia_al_negocio_km : null,
            'costo_envio' => $p->costo_envio,
            'total' => $p->total,
            'metodo_pago' => $p->metodo_pago,
            'tamano' => $p->categoriaVehiculo?->nombre,
            'total_items' => $p->items_count,
            'created_at' => $p->created_at,
        ]));
    }

    /** GET /api/repartidor/pedido-actual — el pedido que lleva ahora ({"pedido": null} si ninguno). */
    public function actual(Request $request): JsonResponse
    {
        $pedido = $this->perfil($request)->pedidos()->whereIn('estado', Pedido::ESTADOS_REPARTO)->latest('id')->first();

        return response()->json(['pedido' => $pedido ? new PedidoResource($this->conDetalle($pedido)) : null]);
    }

    /** POST /api/pedidos/{pedido}/aceptar — lo toma (gana el primero que acepta). */
    public function aceptar(Request $request, Pedido $pedido): PedidoResource
    {
        [$repartidor, $vehiculo] = $this->habilitado($request, enLinea: true);

        return new PedidoResource($this->conDetalle(FlujoPedido::aceptar($pedido, $repartidor, $vehiculo)));
    }

    /** POST /api/pedidos/{pedido}/soltar — antes de recogerlo; vuelve a quedar disponible. */
    public function soltar(Request $request, Pedido $pedido): PedidoResource
    {
        $this->esSuyo($request, $pedido);
        $motivo = $request->validate(['motivo' => ['nullable', 'string', 'max:255']])['motivo'] ?? null;

        return new PedidoResource($this->conDetalle(FlujoPedido::soltar($pedido, $request->user(), $motivo)));
    }

    /**
     * PUT /api/repartidor/pedidos/{pedido}/estado — "en_camino" (ya lo recogió)
     * o "entregado" con el PIN de 4 números que le da el cliente.
     */
    public function estado(Request $request, Pedido $pedido): PedidoResource
    {
        $this->esSuyo($request, $pedido);
        $datos = $request->validate([
            'estado' => ['required', Rule::in(['en_camino', 'entregado'])],
            'codigo' => ['nullable', 'required_if:estado,entregado', 'string', 'digits:4'],
        ], [
            'codigo.required_if' => 'Pídele al cliente su PIN de 4 números.',
            'codigo.digits' => 'El PIN tiene 4 números.',
        ]);

        if ($datos['estado'] === 'entregado' && $datos['codigo'] !== $pedido->codigo_entrega) {
            throw ValidationException::withMessages(['codigo' => 'El PIN no coincide. Pídeselo de nuevo al cliente.']);
        }

        return new PedidoResource($this->conDetalle(FlujoPedido::cambiar($pedido, $datos['estado'], $request->user(), 'repartidor')));
    }

    /** GET /api/repartidor/entregas — pedidos que entregó (más reciente primero), de a 20. */
    public function entregas(Request $request): AnonymousResourceCollection
    {
        $entregados = $this->perfil($request)->pedidos()->where('estado', 'entregado');

        return PedidoResource::collection(
            (clone $entregados)->with('negocio')->withCount('items')->latest('entregado_en')->latest('id')->paginate(20)
        )->additional([
            'resumen' => [
                'entregas' => (clone $entregados)->count(),
                'total_envios' => number_format((float) (clone $entregados)->sum('costo_envio'), 2, '.', ''),
            ],
        ]);
    }

    /** Su perfil de repartidor (403 si no es repartidor). */
    private function perfil(Request $request): Repartidor
    {
        $repartidor = $request->user()->repartidor()->first();
        abort_unless($repartidor, 403, 'Todavía no te registraste como repartidor.');

        return $repartidor;
    }

    /**
     * Aprobado, sin sanción y con su vehículo aprobado (y en línea, si se pide).
     *
     * @return array{0: Repartidor, 1: Vehiculo}
     */
    private function habilitado(Request $request, bool $enLinea = false): array
    {
        $repartidor = $this->perfil($request);
        abort_unless($repartidor->estaAprobado(), 403, 'Tu cuenta de repartidor todavía no está aprobada.');
        abort_if($repartidor->estaSancionado(), 403, 'Tu cuenta de repartidor está suspendida.');
        $vehiculo = $repartidor->vehiculoAprobado();
        abort_unless($vehiculo, 403, 'Tu vehículo todavía no está aprobado.');
        if ($enLinea && ! $repartidor->disponible) {
            abort(422, 'Ponte en línea para ver y aceptar pedidos.');
        }

        return [$repartidor, $vehiculo];
    }

    /** Los pedidos de otro repartidor no existen para él (404). */
    private function esSuyo(Request $request, Pedido $pedido): void
    {
        abort_unless((int) $pedido->repartidor_id === (int) $this->perfil($request)->usuario_id, 404);
    }

    private function conDetalle(Pedido $pedido): Pedido
    {
        return $pedido->refresh()->load([
            'negocio', 'comprador', 'items.producto.imagenPrincipal', 'historial', 'repartidor', 'vehiculo.tipo', 'categoriaVehiculo',
        ]);
    }
}
