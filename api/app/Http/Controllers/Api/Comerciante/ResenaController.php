<?php

namespace App\Http\Controllers\Api\Comerciante;

use App\Http\Controllers\Controller;
use App\Http\Resources\ResenaResource;
use App\Models\Negocio;
use App\Models\Resena;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Calificaciones del negocio y de sus productos: /api/negocios/{negocio}/resenas. */
class ResenaController extends Controller
{
    /** GET ?tipo=negocio|producto — las más recientes primero, con el resumen de estrellas. */
    public function index(Request $request, Negocio $negocio): JsonResponse
    {
        $tipo = $request->validate(['tipo' => ['nullable', Rule::in(['negocio', 'producto'])]])['tipo'] ?? null;

        $resenas = $this->delNegocio($negocio)
            ->with(['autor', 'producto'])
            ->when($tipo, fn ($q) => $q->where('tipo', $tipo))
            ->latest('updated_at')
            ->paginate(30);

        // Cuántas reseñas del negocio tiene con 1, 2, … 5 estrellas.
        $porEstrellas = Resena::where('tipo', 'negocio')->where('negocio_id', $negocio->id)->where('visible', true)
            ->selectRaw('estrellas, COUNT(*) AS total')->groupBy('estrellas')->pluck('total', 'estrellas');

        return response()->json([
            'rating_promedio' => $negocio->rating_promedio,
            'total_resenas' => (int) $negocio->total_resenas,
            'por_estrellas' => collect(range(1, 5))->mapWithKeys(fn ($e) => [(string) $e => (int) ($porEstrellas[$e] ?? 0)]),
            'data' => ResenaResource::collection($resenas->getCollection()),
            'meta' => ['current_page' => $resenas->currentPage(), 'last_page' => $resenas->lastPage()],
        ]);
    }

    /** PUT /{resena}/respuesta — el negocio contesta (se ve debajo de la reseña). */
    public function responder(Request $request, Negocio $negocio, Resena $resena): ResenaResource
    {
        abort_unless($this->delNegocio($negocio)->whereKey($resena->id)->exists(), 404);

        $datos = $request->validate(['respuesta' => ['nullable', 'string', 'max:1000']]);
        $resena->update([
            'respuesta' => $datos['respuesta'] ?: null,
            'respondido_en' => filled($datos['respuesta'] ?? null) ? now() : null,
        ]);

        return new ResenaResource($resena->load(['autor', 'producto']));
    }

    /** Reseñas visibles del negocio y de sus productos. */
    private function delNegocio(Negocio $negocio)
    {
        return Resena::query()
            ->where('visible', true)
            ->where(fn ($q) => $q
                ->where(fn ($q) => $q->where('tipo', 'negocio')->where('negocio_id', $negocio->id))
                ->orWhere(fn ($q) => $q->where('tipo', 'producto')
                    ->whereIn('producto_id', $negocio->productos()->withTrashed()->select('id'))));
    }
}
