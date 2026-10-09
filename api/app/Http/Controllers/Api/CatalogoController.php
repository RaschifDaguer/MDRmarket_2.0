<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoriaResource;
use App\Models\Categoria;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class CatalogoController extends Controller
{
    /** GET /api/categorias — categorías principales con sus subcategorías. */
    public function categorias(): AnonymousResourceCollection
    {
        return CategoriaResource::collection(
            Categoria::principales()->with('subcategorias')->get()
        );
    }
}
