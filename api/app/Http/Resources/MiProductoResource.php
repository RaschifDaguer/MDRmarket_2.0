<?php

namespace App\Http\Resources;

use App\Models\Producto;
use App\Support\Archivos;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Producto tal como lo ve su dueño: incluye el costo, el stock y si está
 * oculto (disponible = false), que el cliente no ve.
 *
 * @mixin Producto
 */
class MiProductoResource extends JsonResource
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
            'precio' => $this->precio,
            'costo' => $this->costo,
            'precio_oferta' => $this->precio_oferta,
            'oferta_inicio' => $this->oferta_inicio,
            'oferta_fin' => $this->oferta_fin,
            'en_oferta' => $this->enOferta(),
            // null = sin control de stock (ej. comida hecha al momento)
            'stock' => $this->stock,
            'disponible' => (bool) $this->disponible,
            'imagen_url' => Archivos::url($this->imagenPrincipal?->url),
            'rating_promedio' => $this->rating_promedio,
            'total_resenas' => (int) $this->total_resenas,
            'total_vendidos' => (int) $this->total_vendidos,
            'created_at' => $this->created_at,
        ];
    }
}
