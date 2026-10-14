<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Reseña pública: solo el nombre del autor (sin apellido completo ni correo). */
class ResenaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $autor = $this->autor;
        $inicial = mb_substr((string) $autor?->apellido, 0, 1);

        return [
            'id' => $this->id,
            'tipo' => $this->tipo,
            'estrellas' => (int) $this->estrellas,
            'comentario' => $this->comentario,
            // "Lucía R." (sin el apellido completo).
            'autor' => $autor ? ($inicial !== '' ? "{$autor->nombre} {$inicial}." : $autor->nombre) : 'Usuario',
            'producto' => $this->when($this->tipo === 'producto', fn () => [
                'id' => $this->producto_id,
                'nombre' => $this->producto?->nombre,
            ]),
            'respuesta' => $this->respuesta,
            'respondido_en' => $this->respondido_en,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
