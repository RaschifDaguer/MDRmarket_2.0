<?php

namespace App\Http\Controllers\Api\Comerciante;

use App\Http\Controllers\Controller;
use App\Models\Negocio;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Números del negocio, con los procedimientos de la base (sp_reporte_negocio
 * y sp_reporte_productos). Las fechas son de Bolivia (AAAA-MM-DD).
 */
class ReporteController extends Controller
{
    private const MONTOS = ['ventas', 'costo_de_lo_vendido', 'ganancia_bruta', 'compras', 'gastos', 'comisiones', 'ganancia_neta', 'flujo_caja'];

    /** GET /api/negocios/{negocio}/resumen — la portada de la vista comerciante. */
    public function resumen(Negocio $negocio): JsonResponse
    {
        $hoy = CarbonImmutable::now('America/La_Paz')->toDateString();
        $inicioMes = CarbonImmutable::now('America/La_Paz')->startOfMonth()->toDateString();

        $productos = $negocio->productos();

        return response()->json([
            'pedidos_nuevos' => $negocio->pedidos()->where('estado', 'pendiente')->count(),
            'pedidos_en_curso' => $negocio->pedidos()->whereIn('estado', ['confirmado', 'preparando', 'listo', 'en_camino'])->count(),
            'hoy' => $this->totales($this->filas($negocio, $hoy, $hoy, 'anio')),
            'mes' => $this->totales($this->filas($negocio, $inicioMes, $hoy, 'anio')),
            'productos_activos' => (clone $productos)->where('disponible', true)->count(),
            'productos_sin_stock' => (clone $productos)->where('disponible', true)->where('stock', 0)->count(),
            'rating_promedio' => $negocio->rating_promedio,
            'total_resenas' => (int) $negocio->total_resenas,
        ]);
    }

    /** GET /api/negocios/{negocio}/reporte?desde&hasta&agrupar=dia|semana|mes|anio */
    public function reporte(Request $request, Negocio $negocio): JsonResponse
    {
        [$desde, $hasta] = $this->rango($request);
        $agrupar = $request->validate(['agrupar' => ['nullable', Rule::in(['dia', 'semana', 'mes', 'anio'])]])['agrupar'] ?? 'dia';

        $filas = $this->filas($negocio, $desde, $hasta, $agrupar);

        return response()->json([
            'desde' => $desde,
            'hasta' => $hasta,
            'agrupar' => $agrupar,
            'totales' => $this->totales($filas),
            'periodos' => array_map(fn ($f) => [
                'periodo' => $f->periodo,
                'desde' => $f->desde,
                'hasta' => $f->hasta,
                ...$this->montos($f),
                'unidades_vendidas' => (int) $f->unidades_vendidas,
            ], $filas),
        ]);
    }

    /** GET /api/negocios/{negocio}/reporte-productos?desde&hasta — gasto y ganancia por producto. */
    public function productos(Request $request, Negocio $negocio): JsonResponse
    {
        [$desde, $hasta] = $this->rango($request);
        $filas = DB::select('CALL sp_reporte_productos(?, ?, ?)', [$negocio->id, $desde, $hasta]);

        return response()->json(array_map(fn ($f) => [
            'producto_id' => (int) $f->producto_id,
            'producto' => $f->producto,
            'unidades_compradas' => (int) $f->unidades_compradas,
            'gasto_en_compras' => $this->dinero($f->gasto_en_compras),
            'unidades_vendidas' => (int) $f->unidades_vendidas,
            'ventas' => $this->dinero($f->ventas),
            'ganancia' => $this->dinero($f->ganancia),
            'margen_pct' => $f->margen_pct === null ? null : (float) $f->margen_pct,
        ], $filas));
    }

    /** desde/hasta (por defecto: este mes). */
    private function rango(Request $request): array
    {
        $datos = $request->validate([
            'desde' => ['nullable', 'date_format:Y-m-d'],
            'hasta' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:desde'],
        ]);
        $ahora = CarbonImmutable::now('America/La_Paz');

        return [
            $datos['desde'] ?? $ahora->startOfMonth()->toDateString(),
            $datos['hasta'] ?? $ahora->toDateString(),
        ];
    }

    private function filas(Negocio $negocio, string $desde, string $hasta, string $agrupar): array
    {
        return DB::select('CALL sp_reporte_negocio(?, ?, ?, ?)', [$negocio->id, $desde, $hasta, $agrupar]);
    }

    private function totales(array $filas): array
    {
        $totales = [];
        foreach (self::MONTOS as $campo) {
            $totales[$campo] = $this->dinero(array_sum(array_map(fn ($f) => (float) $f->$campo, $filas)));
        }
        $totales['unidades_vendidas'] = (int) array_sum(array_map(fn ($f) => (int) $f->unidades_vendidas, $filas));

        return $totales;
    }

    private function montos(object $fila): array
    {
        return collect(self::MONTOS)->mapWithKeys(fn ($campo) => [$campo => $this->dinero($fila->$campo)])->all();
    }

    private function dinero(mixed $valor): string
    {
        return number_format((float) $valor, 2, '.', '');
    }
}
