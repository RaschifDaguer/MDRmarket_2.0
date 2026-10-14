<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Direccion;
use App\Support\Envio;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Direcciones guardadas del cliente para recibir pedidos ("Casa", "Trabajo"…). */
class DireccionController extends Controller
{
    /** GET /api/direcciones — la predeterminada primero. */
    public function index(Request $request): JsonResponse
    {
        return response()->json(
            $request->user()->direcciones()->orderByDesc('predeterminada')->latest('id')->get()->map($this->formato(...))
        );
    }

    /** POST /api/direcciones */
    public function store(Request $request): JsonResponse
    {
        $datos = $this->validar($request);
        $usuario = $request->user();

        $direccion = DB::transaction(function () use ($usuario, $datos) {
            // La primera queda como predeterminada.
            $predeterminada = ($datos['predeterminada'] ?? false) || ! $usuario->direcciones()->exists();
            if ($predeterminada) {
                $usuario->direcciones()->update(['predeterminada' => false]);
            }

            return $usuario->direcciones()->create([...$datos, 'predeterminada' => $predeterminada]);
        });

        return response()->json($this->formato($direccion), 201);
    }

    /** PUT /api/direcciones/{direccion} */
    public function update(Request $request, Direccion $direccion): JsonResponse
    {
        $this->esSuya($request, $direccion);
        $datos = $this->validar($request);

        DB::transaction(function () use ($request, $direccion, $datos) {
            if ($datos['predeterminada'] ?? false) {
                $request->user()->direcciones()->whereKeyNot($direccion->id)->update(['predeterminada' => false]);
            }
            $direccion->update($datos);
        });

        return response()->json($this->formato($direccion->refresh()));
    }

    /** DELETE /api/direcciones/{direccion} — los pedidos viejos guardan su copia del texto. */
    public function destroy(Request $request, Direccion $direccion): JsonResponse
    {
        $this->esSuya($request, $direccion);
        $eraPredeterminada = $direccion->predeterminada;
        $direccion->delete();

        if ($eraPredeterminada) {
            $request->user()->direcciones()->latest('id')->first()?->update(['predeterminada' => true]);
        }

        return response()->json(['message' => 'Dirección eliminada.']);
    }

    private function validar(Request $request): array
    {
        $datos = $request->validate([
            'etiqueta' => ['nullable', 'string', 'max:50'],
            'direccion' => ['required', 'string', 'max:255'],
            'referencia' => ['nullable', 'string', 'max:255'],
            'latitud' => ['required', 'numeric', 'between:-90,90'],
            'longitud' => ['required', 'numeric', 'between:-180,180'],
            'predeterminada' => ['sometimes', 'boolean'],
        ], [
            'latitud.required' => 'Marca la dirección en el mapa o con el GPS.',
            'longitud.required' => 'Marca la dirección en el mapa o con el GPS.',
        ]);
        Envio::exigirCobertura((float) $datos['latitud'], (float) $datos['longitud']);

        return $datos;
    }

    private function esSuya(Request $request, Direccion $direccion): void
    {
        abort_unless((int) $direccion->usuario_id === (int) $request->user()->id, 404);
    }

    private function formato(Direccion $d): array
    {
        return [
            'id' => $d->id,
            'etiqueta' => $d->etiqueta,
            'direccion' => $d->direccion,
            'referencia' => $d->referencia,
            'latitud' => $d->latitud,
            'longitud' => $d->longitud,
            'predeterminada' => (bool) $d->predeterminada,
        ];
    }
}
