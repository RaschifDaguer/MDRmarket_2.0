<?php

namespace App\Http\Controllers\Api\Comerciante;

use App\Http\Controllers\Controller;
use App\Models\Negocio;
use App\Models\RegistroComercio;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Libro de compras, gastos y ventas: /api/negocios/{negocio}/registros.
 * Las ventas las anota la base al entregar un pedido; el comerciante carga
 * compras de mercadería (suman stock y actualizan el costo) y otros gastos.
 */
class RegistroController extends Controller
{
    private const ZONA = 'America/La_Paz';

    /** GET ?tipo=compra|gasto|venta&desde=AAAA-MM-DD&hasta=AAAA-MM-DD (fechas de Bolivia) */
    public function index(Request $request, Negocio $negocio): JsonResponse
    {
        $filtros = $request->validate([
            'tipo' => ['nullable', Rule::in(['compra', 'gasto', 'venta', 'comision'])],
            'desde' => ['nullable', 'date_format:Y-m-d'],
            'hasta' => ['nullable', 'date_format:Y-m-d'],
        ]);

        $registros = $negocio->registros()
            ->with('producto')
            ->when($filtros['tipo'] ?? null, fn ($q, $tipo) => $q->where('tipo', $tipo))
            ->when($filtros['desde'] ?? null, fn ($q, $d) => $q->where('fecha', '>=', CarbonImmutable::parse($d, self::ZONA)->utc()))
            ->when($filtros['hasta'] ?? null, fn ($q, $h) => $q->where('fecha', '<', CarbonImmutable::parse($h, self::ZONA)->addDay()->utc()))
            ->orderByDesc('fecha')
            ->orderByDesc('id')
            ->paginate(30);

        return response()->json([
            'data' => $registros->getCollection()->map($this->formato(...)),
            'meta' => ['current_page' => $registros->currentPage(), 'last_page' => $registros->lastPage(), 'total' => $registros->total()],
        ]);
    }

    /**
     * POST — compra: producto_id, cantidad, costo_unitario (por unidad), proveedor.
     *        gasto:  descripcion y monto (alquiler, luz, bolsas…).
     * fecha opcional (AAAA-MM-DD, hora de Bolivia); por defecto, ahora.
     */
    public function store(Request $request, Negocio $negocio): JsonResponse
    {
        $datos = $request->validate([
            'tipo' => ['required', Rule::in(['compra', 'gasto'])],
            'producto_id' => ['required_if:tipo,compra', 'nullable', 'integer'],
            'cantidad' => ['required_if:tipo,compra', 'nullable', 'integer', 'min:1', 'max:100000'],
            'costo_unitario' => ['required_if:tipo,compra', 'nullable', 'numeric', 'min:0', 'max:999999'],
            'monto' => ['required_if:tipo,gasto', 'nullable', 'numeric', 'min:0.01', 'max:9999999'],
            'descripcion' => ['required_if:tipo,gasto', 'nullable', 'string', 'max:255'],
            'proveedor' => ['nullable', 'string', 'max:150'],
            'fecha' => ['nullable', 'date_format:Y-m-d', 'before_or_equal:today'],
        ], [
            'producto_id.required_if' => 'Elige qué producto compraste.',
            'cantidad.required_if' => 'Escribe cuántas unidades compraste.',
            'costo_unitario.required_if' => 'Escribe cuánto te costó cada unidad.',
            'monto.required_if' => 'Escribe cuánto gastaste.',
            'descripcion.required_if' => 'Escribe en qué gastaste (ej. "alquiler de octubre").',
            'fecha.before_or_equal' => 'La fecha no puede ser del futuro.',
        ]);

        if ($datos['tipo'] === 'compra' && ! $negocio->productos()->whereKey($datos['producto_id'])->exists()) {
            throw ValidationException::withMessages(['producto_id' => 'Elige uno de tus productos.']);
        }

        // Sin fecha = ahora. Con fecha = ese día a mediodía (hora de Bolivia), guardado en UTC.
        $fecha = isset($datos['fecha'])
            ? CarbonImmutable::parse($datos['fecha'].' 12:00', self::ZONA)->utc()
            : now();

        $registro = $negocio->registros()->create($datos['tipo'] === 'compra' ? [
            'tipo' => 'compra',
            'producto_id' => $datos['producto_id'],
            'cantidad' => $datos['cantidad'],
            'costo_unitario' => $datos['costo_unitario'],
            'descripcion' => $datos['descripcion'] ?? null,
            'proveedor' => $datos['proveedor'] ?? null,
            'fecha' => $fecha,
            'registrado_por' => $request->user()->id,
        ] : [
            'tipo' => 'gasto',
            'cantidad' => 1,
            'costo_unitario' => $datos['monto'],
            'descripcion' => $datos['descripcion'],
            'proveedor' => $datos['proveedor'] ?? null,
            'fecha' => $fecha,
            'registrado_por' => $request->user()->id,
        ]);

        return response()->json($this->formato($registro->refresh()->load('producto')), 201);
    }

    /** DELETE /{registro} — solo compras y gastos. Borrar una compra resta su stock. */
    public function destroy(Negocio $negocio, RegistroComercio $registro): JsonResponse
    {
        if (! in_array($registro->tipo, ['compra', 'gasto'], true)) {
            throw ValidationException::withMessages(['registro' => 'Las ventas se anotan solas al entregar un pedido: no se borran.']);
        }

        DB::transaction(function () use ($registro) {
            if ($registro->tipo === 'compra' && $registro->producto_id) {
                DB::update(
                    'UPDATE producto SET stock = GREATEST(CAST(stock AS SIGNED) - ?, 0) WHERE id = ? AND stock IS NOT NULL',
                    [$registro->cantidad, $registro->producto_id]
                );
            }
            $registro->delete();
        });

        return response()->json(['message' => 'Registro eliminado.']);
    }

    private function formato(RegistroComercio $r): array
    {
        return [
            'id' => $r->id,
            'tipo' => $r->tipo,
            'producto' => $r->producto ? ['id' => $r->producto->id, 'nombre' => $r->producto->nombre] : null,
            'pedido_id' => $r->pedido_id,
            'cantidad' => $r->cantidad,
            'precio_unitario' => $r->precio_unitario,
            'costo_unitario' => $r->costo_unitario,
            // Lo que entró (venta) o salió (compra, gasto, comisión).
            'monto' => $r->tipo === 'venta' ? $r->ingreso : $r->egreso,
            'ganancia' => $r->tipo === 'venta' ? $r->ganancia : null,
            'descripcion' => $r->descripcion,
            'proveedor' => $r->proveedor,
            'fecha' => $r->fecha,
        ];
    }
}
