<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MotivoReporte;
use App\Models\Pedido;
use App\Models\Reporte;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * "Hubo un problema" con un pedido: el cliente reporta a la tienda o al
 * repartidor. Lo revisa el equipo de MDR Market (admin).
 */
class ReporteProblemaController extends Controller
{
    /** GET /api/motivos-reporte?tipo=negocio|repartidor — motivos que se pueden elegir. */
    public function motivos(Request $request): JsonResponse
    {
        $tipo = $request->validate(['tipo' => ['required', Rule::in(['negocio', 'repartidor'])]])['tipo'];

        return response()->json(
            MotivoReporte::where('activo', true)->orderBy('id')->get()
                ->filter(fn (MotivoReporte $m) => $m->aplicaA($tipo))
                ->map(fn (MotivoReporte $m) => ['codigo' => $m->codigo, 'nombre' => $m->nombre])
                ->values()
        );
    }

    /**
     * POST /api/pedidos/{pedido}/reportes — el comprador reporta un problema
     * con la tienda o con el repartidor de su pedido. Uno abierto por cada uno.
     */
    public function store(Request $request, Pedido $pedido): JsonResponse
    {
        $usuario = $request->user();
        abort_unless((int) $pedido->comprador_id === (int) $usuario->id, 404);

        $datos = $request->validate([
            'sobre' => ['required', Rule::in(['negocio', 'repartidor'])],
            'motivo' => ['required', 'string'],
            'descripcion' => ['nullable', 'string', 'max:1000'],
        ], [
            'sobre.in' => 'Elige si el problema fue con la tienda o con el repartidor.',
            'motivo.required' => 'Elige qué pasó.',
        ]);

        if ($datos['sobre'] === 'repartidor' && $pedido->repartidor_id === null) {
            throw ValidationException::withMessages(['sobre' => 'Este pedido no tuvo repartidor.']);
        }
        $motivo = MotivoReporte::where('codigo', $datos['motivo'])->where('activo', true)->first();
        if (! $motivo || ! $motivo->aplicaA($datos['sobre'])) {
            throw ValidationException::withMessages(['motivo' => 'Elige un motivo de la lista.']);
        }

        try {
            $reporte = Reporte::create([
                'reportante_id' => $usuario->id,
                'tipo' => $datos['sobre'],
                ...($datos['sobre'] === 'negocio' ? ['negocio_id' => $pedido->negocio_id] : ['repartidor_id' => $pedido->repartidor_id]),
                'motivo_id' => $motivo->id,
                'pedido_id' => $pedido->id,
                'descripcion' => $datos['descripcion'] ?? null,
            ]);
        } catch (QueryException $e) {
            // uq_reporte_abierto: ya tiene uno sin resolver contra lo mismo.
            if (($e->errorInfo[1] ?? null) === 1062) {
                throw ValidationException::withMessages([
                    'sobre' => 'Ya nos contaste un problema con '.($datos['sobre'] === 'negocio' ? 'esta tienda' : 'este repartidor')
                        .'. Lo estamos revisando.',
                ]);
            }
            throw $e;
        }

        return response()->json([
            'id' => $reporte->id,
            'sobre' => $reporte->tipo,
            'motivo' => $motivo->nombre,
            'estado' => 'pendiente',
            'mensaje' => 'Gracias por avisarnos. El equipo de MDR Market lo va a revisar.',
        ], 201);
    }
}
