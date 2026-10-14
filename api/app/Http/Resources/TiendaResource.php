<?php

namespace App\Http\Resources;

use App\Support\Archivos;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Negocio tal como lo ve el cliente (sin NIT ni datos del dueño).
 *
 * @mixin \App\Models\Negocio
 */
class TiendaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nombre' => $this->nombre,
            'descripcion' => $this->descripcion,
            'categoria' => $this->whenLoaded('categoria', fn () => $this->categoria ? [
                'id' => $this->categoria->id,
                'nombre' => $this->categoria->nombre,
                'icono' => $this->categoria->icono,
            ] : null),
            'logo_url' => Archivos::url($this->logo_url),
            'telefono' => $this->telefono,
            'direccion' => $this->direccion,
            'referencia' => $this->referencia,
            'latitud' => $this->latitud,
            'longitud' => $this->longitud,
            'abierto' => (bool) $this->abierto,
            'rating_promedio' => $this->rating_promedio,
            'total_resenas' => (int) $this->total_resenas,
            'tiempo_preparacion_min' => $this->tiempo_preparacion_min,
            'pedido_minimo' => $this->pedido_minimo,
            'total_productos' => $this->whenCounted('productos'),
            'horarios' => $this->whenLoaded('horarios', fn () => $this->horarios->map(fn ($h) => [
                'dia_semana' => $h->dia_semana,
                'hora_apertura' => substr($h->hora_apertura, 0, 5),
                'hora_cierre' => substr($h->hora_cierre, 0, 5),
            ])),
        ];
    }
}
