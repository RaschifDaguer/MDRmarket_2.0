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
     * PUT /api/resenas — crea o edita la reseña del usuario para un producto,
     * negocio o repartidor (una sola por cada uno). Al repartidor se le pueden
     * marcar etiquetas ("Puntual", "Amable", "Cuidó el paquete"). La base exige
     * haber recibido un pedido y no reseñarse a sí mismo (si no, responde 422
     * con el motivo).
     */
    public function guardar(Request $request): ResenaResource
    {
        $datos = $request->validate([
            'tipo' => ['required', Rule::in(['producto', 'negocio', 'repartidor'])],
            'producto_id' => ['required_if:tipo,producto', 'nullable', 'integer'],
            'negocio_id' => ['required_if:tipo,negocio', 'nullable', 'integer'],
            'repartidor_id' => ['required_if:tipo,repartidor', 'nullable', 'integer'],
            'estrellas' => ['required', 'integer', 'between:1,5'],
            'comentario' => ['nullable', 'string', 'max:1000'],
            'etiquetas' => ['nullable', 'array', 'prohibited_unless:tipo,repartidor'],
            'etiquetas.*' => ['string', 'distinct', Rule::in(Resena::ETIQUETAS_REPARTIDOR)],
        ], [
            'estrellas.required' => 'Elige de 1 a 5 estrellas.',
            'etiquetas.prohibited_unless' => 'Las etiquetas son solo para calificar al repartidor.',
            'etiquetas.*.in' => 'Elige etiquetas de la lista: '.implode(', ', Resena::ETIQUETAS_REPARTIDOR).'.',
        ]);

        $objetivo = match ($datos['tipo']) {
            'producto' => ['producto_id' => $datos['producto_id']],
            'negocio' => ['negocio_id' => $datos['negocio_id']],
            'repartidor' => ['repartidor_id' => $datos['repartidor_id']],
        };

        $resena = Resena::updateOrCreate(
            ['autor_id' => $request->user()->id, 'tipo' => $datos['tipo'], ...$objetivo],
            [
                'estrellas' => $datos['estrellas'],
                'comentario' => $datos['comentario'] ?? null,
                // Sin etiquetas (o lista vacía) se guarda NULL.
                'etiquetas' => $datos['tipo'] === 'repartidor' && ! empty($datos['etiquetas']) ? array_values($datos['etiquetas']) : null,
            ],
        );

        return new ResenaResource($resena->load(['autor', 'producto']));
    }
}
