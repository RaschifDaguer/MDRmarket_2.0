<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PedidoResource;
use App\Models\Configuracion;
use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\Producto;
use App\Support\Envio;
use App\Support\FlujoPedido;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/** Pedidos del cliente: cotizar el envío, pedir, ver y cancelar. */
class PedidoController extends Controller
{
    /** Pedidos "pendientes" (sin respuesta del negocio) que puede tener un cliente a la vez. */
    public const MAXIMO_PENDIENTES = 5;

    /**
     * POST /api/envio/cotizar — cuánto cuesta el envío desde el negocio hasta
     * la dirección. 422 en "latitud" si está fuera de cobertura.
     */
    public function cotizar(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'negocio_id' => ['required', 'integer'],
            'latitud' => ['required', 'numeric', 'between:-90,90'],
            'longitud' => ['required', 'numeric', 'between:-180,180'],
            'productos' => ['sometimes', 'array', 'max:50'],
            'productos.*' => ['integer'],
        ]);
        $negocio = $this->negocioDisponible((int) $datos['negocio_id']);

        return response()->json(Envio::cotizar(
            $negocio, (float) $datos['latitud'], (float) $datos['longitud'],
            $this->categoriaVehiculo(collect($datos['productos'] ?? []))
        ));
    }

    /**
     * POST /api/pedidos — hace el pedido a UN negocio. El precio de cada
     * producto sale del catálogo (con la oferta vigente), no de la app.
     */
    public function store(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'negocio_id' => ['required', 'integer'],
            'direccion_id' => ['nullable', 'integer'],
            'direccion' => ['required_without:direccion_id', 'nullable', 'string', 'max:255'],
            'referencia' => ['nullable', 'string', 'max:255'],
            'latitud' => ['required_without:direccion_id', 'nullable', 'numeric', 'between:-90,90'],
            'longitud' => ['required_without:direccion_id', 'nullable', 'numeric', 'between:-180,180'],
            'notas' => ['nullable', 'string', 'max:500'],
            'metodo_pago' => ['required', Rule::in(['efectivo', 'qr', 'transferencia'])],
            'items' => ['required', 'array', 'min:1', 'max:50'],
            'items.*.producto_id' => ['required', 'integer', 'distinct'],
            'items.*.cantidad' => ['required', 'integer', 'min:1', 'max:99'],
            'items.*.notas' => ['nullable', 'string', 'max:255'],
        ], [
            'items.required' => 'Tu carrito está vacío.',
            'direccion.required_without' => 'Elige o escribe la dirección de entrega.',
            'latitud.required_without' => 'Marca la dirección de entrega en el mapa.',
        ]);

        $usuario = $request->user();
        $negocio = $this->negocioDisponible((int) $datos['negocio_id']);
        if ((int) $negocio->usuario_id === (int) $usuario->id) {
            throw ValidationException::withMessages(['negocio_id' => 'No puedes hacer pedidos a tu propio negocio.']);
        }

        // Contra pedidos falsos en masa: pocos pedidos esperando respuesta a la vez.
        if ($usuario->pedidos()->where('estado', 'pendiente')->count() >= self::MAXIMO_PENDIENTES) {
            throw ValidationException::withMessages([
                'pedido' => 'Tienes '.self::MAXIMO_PENDIENTES.' pedidos esperando respuesta. Espera a que los acepten o cancela alguno.',
            ]);
        }

        // Dirección: una guardada o la que mandó la app.
        $direccion = null;
        if (! empty($datos['direccion_id'])) {
            $direccion = $usuario->direcciones()->find($datos['direccion_id'])
                ?? throw ValidationException::withMessages(['direccion_id' => 'Elige una de tus direcciones.']);
        }
        $latitud = (float) ($direccion->latitud ?? $datos['latitud']);
        $longitud = (float) ($direccion->longitud ?? $datos['longitud']);

        $items = collect($datos['items']);
        $catalogo = $this->productosDelCatalogo($negocio, $items);
        $subtotal = $items->sum(fn ($i) => (float) $catalogo[$i['producto_id']]->precio_final * $i['cantidad']);

        if ($subtotal < (float) $negocio->pedido_minimo) {
            throw ValidationException::withMessages([
                'items' => 'El pedido mínimo de este negocio es Bs '.number_format((float) $negocio->pedido_minimo, 2).'.',
            ]);
        }

        $categoriaVehiculo = $this->categoriaVehiculo($items->pluck('producto_id'));
        $envio = Envio::cotizar($negocio, $latitud, $longitud, $categoriaVehiculo);
        $comisionPct = (float) Configuracion::valor('comision_plataforma_pct', 0);

        $pedido = DB::transaction(function () use ($usuario, $negocio, $direccion, $datos, $latitud, $longitud, $items, $catalogo, $subtotal, $categoriaVehiculo, $envio, $comisionPct) {
            $pedido = Pedido::create([
                'comprador_id' => $usuario->id,
                'negocio_id' => $negocio->id,
                'direccion_id' => $direccion?->id,
                'direccion_entrega' => $direccion->direccion ?? $datos['direccion'],
                'referencia_entrega' => $direccion->referencia ?? ($datos['referencia'] ?? null),
                'latitud_entrega' => $latitud,
                'longitud_entrega' => $longitud,
                'notas' => $datos['notas'] ?? null,
                'categoria_vehiculo_requerida_id' => $categoriaVehiculo,
                'subtotal' => $subtotal,
                'costo_envio' => $envio['costo_envio'],
                'tarifa_servicio' => $envio['tarifa_servicio'],
                'comision_plataforma' => round($subtotal * $comisionPct / 100, 2),
                'metodo_pago' => $datos['metodo_pago'],
                'codigo_entrega' => str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT),
                'distancia_km' => $envio['distancia_km'],
                'tiempo_estimado_min' => $negocio->tiempo_preparacion_min,
            ]);

            // Cada ítem descuenta el stock en la base (trg_pedido_item_bi). Si
            // otro cliente se llevó la última unidad, falla y no se guarda nada.
            foreach ($items as $item) {
                $pedido->items()->create([
                    'producto_id' => $item['producto_id'],
                    'producto_nombre' => $catalogo[$item['producto_id']]->nombre,
                    'precio_unitario' => $catalogo[$item['producto_id']]->precio_final,
                    'cantidad' => $item['cantidad'],
                    'notas' => $item['notas'] ?? null,
                ]);
            }

            $pedido->registrarEstado(null, 'pendiente', $usuario->id, 'cliente');

            return $pedido;
        });

        Notificacion::avisar($negocio->usuario_id, 'pedido_nuevo', "¡Nuevo pedido #{$pedido->id}!",
            $items->sum('cantidad').' producto(s) · Bs '.number_format($subtotal, 2), $pedido->id);

        return (new PedidoResource($this->conDetalle($pedido)))->response()->setStatusCode(201);
    }

    /** GET /api/pedidos — mis pedidos como comprador, del más reciente al más antiguo. */
    public function index(Request $request): AnonymousResourceCollection
    {
        return PedidoResource::collection(
            $request->user()->pedidos()->with('negocio')->withCount('items')->latest('id')->paginate(20)
        );
    }

    /** GET /api/pedidos/{pedido} — lo ven el comprador y el dueño del negocio. */
    public function show(Request $request, Pedido $pedido): PedidoResource
    {
        $usuarioId = (int) $request->user()->id;
        abort_unless(
            (int) $pedido->comprador_id === $usuarioId || (int) $pedido->negocio->usuario_id === $usuarioId,
            404
        );

        return new PedidoResource($this->conDetalle($pedido));
    }

    /** POST /api/pedidos/{pedido}/cancelar — solo mientras el negocio no lo aceptó. */
    public function cancelar(Request $request, Pedido $pedido): PedidoResource
    {
        abort_unless((int) $pedido->comprador_id === (int) $request->user()->id, 404);
        $motivo = $request->validate(['motivo' => ['nullable', 'string', 'max:255']])['motivo'] ?? null;

        $pedido = FlujoPedido::cambiar($pedido, 'cancelado', $request->user(), 'cliente', $motivo);

        return new PedidoResource($this->conDetalle($pedido));
    }

    /** refresh(): estado, total y fechas los pone la base al guardar. */
    private function conDetalle(Pedido $pedido): Pedido
    {
        return $pedido->refresh()->load(['negocio', 'comprador', 'items.producto.imagenPrincipal', 'historial']);
    }

    /** Aprobado, sin sanción y abierto; si no, 422 en "negocio_id". */
    private function negocioDisponible(int $id): Negocio
    {
        $negocio = Negocio::find($id);
        if (! $negocio || ! $negocio->estaAprobado() || DB::scalar('SELECT fn_negocio_sancionado(?)', [$id])) {
            throw ValidationException::withMessages(['negocio_id' => 'Este negocio no está disponible.']);
        }
        if (! $negocio->abierto) {
            throw ValidationException::withMessages(['negocio_id' => 'El negocio está cerrado en este momento.']);
        }

        return $negocio;
    }

    /**
     * Filas del catálogo de los productos pedidos (precio final vigente).
     * Revisa que sigan disponibles y que alcance el stock.
     *
     * @return Collection<int, object>
     */
    private function productosDelCatalogo(Negocio $negocio, Collection $items): Collection
    {
        $catalogo = DB::table('v_catalogo_producto')
            ->where('negocio_id', $negocio->id)
            ->whereIn('id', $items->pluck('producto_id'))
            ->get()
            ->keyBy('id');

        foreach ($items->values() as $i => $item) {
            $producto = $catalogo[$item['producto_id']] ?? null;
            if (! $producto) {
                throw ValidationException::withMessages([
                    "items.$i.producto_id" => 'Un producto de tu carrito ya no está disponible. Quítalo para continuar.',
                ]);
            }
            if ($producto->stock !== null && (int) $producto->stock < $item['cantidad']) {
                throw ValidationException::withMessages([
                    "items.$i.cantidad" => (int) $producto->stock === 0
                        ? "«{$producto->nombre}» se agotó."
                        : "Solo quedan {$producto->stock} de «{$producto->nombre}».",
                ]);
            }
        }

        return $catalogo;
    }

    /** Vehículo mínimo para llevar todo (1 liviano, 2 mediano, 3 grande). */
    private function categoriaVehiculo(Collection $productoIds): int
    {
        if ($productoIds->isEmpty()) {
            return 1;
        }

        return (int) (Producto::whereIn('id', $productoIds)->max('categoria_vehiculo_id') ?? 1);
    }
}
