<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ResenaResource;
use App\Models\Resena;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ResenaController extends Controller
{
    /**
     * PUT /api/resenas — crea o edita la reseña del usuario para un producto o
     * negocio (una sola por cada uno). La base exige haber recibido un pedido
     * y no reseñarse a sí mismo (si no, responde 422 con el motivo).
     */
    public function guardar(Request $request): ResenaResource
    {
        $datos = $request->validate([
            'tipo' => ['required', Rule::in(['producto', 'negocio'])],
            'producto_id' => ['required_if:tipo,producto', 'nullable', 'integer'],
            'negocio_id' => ['required_if:tipo,negocio', 'nullable', 'integer'],
            'estrellas' => ['required', 'integer', 'between:1,5'],
            'comentario' => ['nullable', 'string', 'max:1000'],
        ], [
            'estrellas.required' => 'Elige de 1 a 5 estrellas.',
        ]);

        $objetivo = $datos['tipo'] === 'producto'
            ? ['producto_id' => $datos['producto_id']]
            : ['negocio_id' => $datos['negocio_id']];

        $resena = Resena::updateOrCreate(
            ['autor_id' => $request->user()->id, 'tipo' => $datos['tipo'], ...$objetivo],
            ['estrellas' => $datos['estrellas'], 'comentario' => $datos['comentario'] ?? null],
        );

        return new ResenaResource($resena->load(['autor', 'producto']));
    }
}
