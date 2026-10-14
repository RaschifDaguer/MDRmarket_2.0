<?php

namespace App\Http\Controllers\Api\Comerciante;

use App\Http\Controllers\Controller;
use App\Http\Requests\ProductoRequest;
use App\Http\Resources\MiProductoResource;
use App\Models\Negocio;
use App\Models\Producto;
use App\Support\Archivos;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Mis productos: /api/negocios/{negocio}/productos (solo el dueño). */
class ProductoController extends Controller
{
    /** GET — todos, también los ocultos. Filtro opcional: q. */
    public function index(Request $request, Negocio $negocio): AnonymousResourceCollection
    {
        $texto = $request->query('q');

        return MiProductoResource::collection(
            $negocio->productos()
                ->with(['categoria', 'imagenPrincipal'])
                ->when($texto, fn ($q) => $q->where('nombre', 'like', '%'.addcslashes($texto, '%_\\').'%'))
                ->orderByDesc('disponible')
                ->orderBy('nombre')
                ->get()
        );
    }

    /** POST — producto nuevo (multipart; la foto es opcional). */
    public function store(ProductoRequest $request, Negocio $negocio): JsonResponse
    {
        $producto = DB::transaction(function () use ($request, $negocio) {
            $producto = $negocio->productos()->create($request->datosProducto());
            if ($request->hasFile('foto')) {
                $this->guardarFoto($producto, $request->file('foto'));
            }

            return $producto;
        });

        return (new MiProductoResource($this->cargar($producto)))->response()->setStatusCode(201);
    }

    /** POST /{producto} — editar (multipart). Con foto nueva, reemplaza la principal. */
    public function update(ProductoRequest $request, Negocio $negocio, Producto $producto): MiProductoResource
    {
        DB::transaction(function () use ($request, $producto) {
            $producto->update($request->datosProducto());
            if ($request->hasFile('foto')) {
                $this->guardarFoto($producto, $request->file('foto'));
            }
        });

        return new MiProductoResource($this->cargar($producto));
    }

    /** PATCH /{producto}/disponible — mostrar u ocultar en el catálogo, sin editar lo demás. */
    public function disponible(Request $request, Negocio $negocio, Producto $producto): MiProductoResource
    {
        $producto->update($request->validate(['disponible' => ['required', 'boolean']]));

        return new MiProductoResource($this->cargar($producto));
    }

    /** DELETE /{producto} — sale del catálogo; los pedidos viejos lo siguen mostrando. */
    public function destroy(Negocio $negocio, Producto $producto): JsonResponse
    {
        $producto->delete();

        return response()->json(['message' => 'Producto eliminado.']);
    }

    private function guardarFoto(Producto $producto, UploadedFile $foto): void
    {
        $anterior = $producto->imagenPrincipal;
        $url = Archivos::guardarPublico($foto, 'productos');

        if ($anterior) {
            Archivos::borrarPublico($anterior->url);
            $anterior->update(['url' => $url]);
        } else {
            $producto->imagenes()->create(['url' => $url, 'es_principal' => true, 'orden' => 0]);
        }
    }

    private function cargar(Producto $producto): Producto
    {
        return $producto->refresh()->load(['categoria', 'imagenPrincipal']);
    }
}
