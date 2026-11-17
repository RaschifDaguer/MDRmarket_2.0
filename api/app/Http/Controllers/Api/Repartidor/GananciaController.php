<?php

namespace App\Http\Controllers\Api\Repartidor;

use App\Http\Controllers\Controller;
use App\Models\Repartidor;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Lo que gana el repartidor: todo el costo de envío de cada pedido que
 * entrega (la comisión de la plataforma se cobra al negocio, no al envío).
 * Días y semanas en hora de Bolivia; la semana va de lunes a domingo.
 */
class GananciaController extends Controller
{
    private const DIAS = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    /** GET /api/repartidor/ganancias — hoy, la semana (por día), su meta y su calificación. */
    public function index(Request $request): JsonResponse
    {
        $repartidor = $this->perfil($request);
        $ahora = CarbonImmutable::now('America/La_Paz');
        $inicioSemana = $ahora->startOfWeek(CarbonImmutable::MONDAY)->startOfDay();

        // Entregas de esta semana, con su día en hora de Bolivia.
        $entregas = $repartidor->pedidos()
            ->where('estado', 'entregado')
            ->where('entregado_en', '>=', $inicioSemana->utc())
            ->get(['id', 'costo_envio', 'entregado_en'])
            ->groupBy(fn ($p) => $p->entregado_en->copy()->setTimezone('America/La_Paz')->toDateString());

        $porDia = [];
        foreach (range(0, 6) as $i) {
            $fecha = $inicioSemana->addDays($i)->toDateString();
            $delDia = $entregas->get($fecha, collect());
            $porDia[] = [
                'fecha' => $fecha,
                'dia' => self::DIAS[$i],
                'entregas' => $delDia->count(),
                'ganado' => $this->dinero($delDia->sum('costo_envio')),
            ];
        }
        $hoy = collect($porDia)->firstWhere('fecha', $ahora->toDateString());
        $mejor = collect($porDia)->sortByDesc(fn ($d) => (float) $d['ganado'])->first();
        $meta = $repartidor->meta_diaria !== null ? (float) $repartidor->meta_diaria : null;

        return response()->json([
            'hoy' => ['entregas' => $hoy['entregas'], 'ganado' => $hoy['ganado']],
            'semana' => [
                'desde' => $inicioSemana->toDateString(),
                'entregas' => array_sum(array_column($porDia, 'entregas')),
                'ganado' => $this->dinero(array_sum(array_map(fn ($d) => (float) $d['ganado'], $porDia))),
                'por_dia' => $porDia,
                // Null si todavía no entregó nada esta semana.
                'mejor_dia' => (float) $mejor['ganado'] > 0 ? $mejor['fecha'] : null,
            ],
            'meta_diaria' => $meta !== null ? $this->dinero($meta) : null,
            // % de la meta de hoy (puede pasar de 100). Null sin meta.
            'progreso_meta_pct' => $meta ? (int) floor((float) $hoy['ganado'] / $meta * 100) : null,
            'calificacion' => $repartidor->rating_promedio,
            'total_resenas' => (int) $repartidor->total_resenas,
            'total_entregas' => (int) $repartidor->total_entregas,
        ]);
    }

    /** PUT /api/repartidor/meta — elige su meta de ganancia del día (null = sin meta). */
    public function meta(Request $request): JsonResponse
    {
        $repartidor = $this->perfil($request);
        $datos = $request->validate([
            'meta_diaria' => ['present', 'nullable', 'numeric', 'min:1', 'max:10000'],
        ], [
            'meta_diaria.min' => 'La meta tiene que ser de al menos Bs 1.',
            'meta_diaria.max' => 'La meta no puede pasar de Bs 10.000.',
        ]);

        $repartidor->forceFill(['meta_diaria' => $datos['meta_diaria']])->save();

        return $this->index($request);
    }

    private function perfil(Request $request): Repartidor
    {
        $repartidor = $request->user()->repartidor()->first();
        abort_unless($repartidor, 403, 'Todavía no te registraste como repartidor.');

        return $repartidor;
    }

    private function dinero(float|int|string $valor): string
    {
        return number_format((float) $valor, 2, '.', '');
    }
}
