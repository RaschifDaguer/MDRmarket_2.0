<?php

namespace App\Http\Resources;

use App\Support\Archivos;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Producto tal como lo ve el cliente: una fila de la vista v_catalogo_producto
 * (precio final con la oferta vigente, sin negocios sancionados ni sin aprobar).
 */
class ProductoCatalogoResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (int) $this->id,
            'nombre' => $this->nombre,
            'descripcion' => $this->descripcion,
            'precio' => $this->precio,
            'precio_final' => $this->precio_final,
            'en_oferta' => (bool) $this->en_oferta,
            'descuento_pct' => (int) $this->descuento_pct,
            // null = sin control de stock (ej. comida hecha al momento)
            'stock' => $this->stock === null ? null : (int) $this->stock,
            'rating_promedio' => $this->rating_promedio === null ? null : (float) $this->rating_promedio,
            'total_resenas' => (int) $this->total_resenas,
            'total_vendidos' => (int) $this->total_vendidos,
            'imagen_url' => Archivos::url($this->imagen_url),
            'categoria' => [
                'id' => (int) $this->categoria_id,
                'nombre' => $this->categoria,
                'icono' => $this->categoria_icono,
            ],
            'categoria_principal' => [
                'id' => (int) $this->categoria_principal_id,
                'nombre' => $this->categoria_principal,
            ],
            'negocio' => [
                'id' => (int) $this->negocio_id,
                'nombre' => $this->negocio,
                'logo_url' => Archivos::url($this->negocio_logo),
                'rating_promedio' => $this->negocio_rating === null ? null : (float) $this->negocio_rating,
                'abierto' => (bool) $this->negocio_abierto,
            ],
        ];
    }
}
