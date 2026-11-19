<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CategoriaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nombre' => $this->nombre,
            'icono' => $this->icono,
            // Bebidas alcohólicas: solo mayores de 18.
            'solo_mayores' => (bool) $this->solo_mayores,
            // Permiso que necesita el negocio para vender aquí: alcohol | farmacia | null.
            'permiso' => $this->permiso,
            'subcategorias' => CategoriaResource::collection($this->whenLoaded('subcategorias')),
        ];
    }
}
