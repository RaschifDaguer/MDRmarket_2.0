<?php

namespace App\Http\Resources;

use App\Support\Archivos;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class NegocioResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nombre' => $this->nombre,
            'descripcion' => $this->descripcion,
            'categoria' => $this->whenLoaded('categoria', fn () => [
                'id' => $this->categoria->id,
                'nombre' => $this->categoria->nombre,
                'icono' => $this->categoria->icono,
            ]),
            'telefono' => $this->telefono,
            'nit' => $this->nit,
            'razon_social' => $this->razon_social,
            'direccion' => $this->direccion,
            'referencia' => $this->referencia,
            'latitud' => $this->latitud,
            'longitud' => $this->longitud,
            'logo_url' => Archivos::url($this->logo_url),
            'abierto' => (bool) $this->abierto,
            'tiempo_preparacion_min' => $this->tiempo_preparacion_min,
            'pedido_minimo' => $this->pedido_minimo,
            'horarios' => $this->whenLoaded('horarios', fn () => $this->horarios->map(fn ($h) => [
                'dia_semana' => $h->dia_semana,
                'hora_apertura' => substr($h->hora_apertura, 0, 5),
                'hora_cierre' => substr($h->hora_cierre, 0, 5),
            ])),
            // pendiente | aprobado | rechazado | suspendido (lo cambia un administrador)
            'estado_verificacion' => $this->estado_verificacion,
            'rating_promedio' => $this->rating_promedio,
            'total_resenas' => (int) $this->total_resenas,
            'created_at' => $this->created_at,
        ];
    }
}
