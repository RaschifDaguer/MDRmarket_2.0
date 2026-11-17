<?php

namespace App\Http\Controllers\Api\Comerciante;

use App\Http\Controllers\Controller;
use App\Http\Requests\ProductoRequest;
use App\Http\Resources\MiProductoResource;
use App\Models\Negocio;
use App\Models\Producto;
use App\Models\ProductoImagen;
use App\Support\Archivos;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

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
            $this->agregarFotos($producto, $request->file('fotos', []));

            return $producto;
        });

        return (new MiProductoResource($this->cargar($producto)))->response()->setStatusCode(201);
    }

    /**
     * POST /{producto} — editar (multipart). Con `foto` reemplaza la portada;
     * con `fotos[]` agrega fotos (hasta 4 en total).
     */
    public function update(ProductoRequest $request, Negocio $negocio, Producto $producto): MiProductoResource
    {
        DB::transaction(function () use ($request, $producto) {
            $producto->update($request->datosProducto());
            if ($request->hasFile('foto')) {
                $this->guardarFoto($producto, $request->file('foto'));
            }
            $this->agregarFotos($producto, $request->file('fotos', []));
        });

        return new MiProductoResource($this->cargar($producto));
    }

    /** DELETE /{producto}/fotos/{imagen} — quita una foto; si era la portada, pasa a serlo la siguiente. */
    public function borrarFoto(Negocio $negocio, Producto $producto, int $imagen): MiProductoResource
    {
        DB::transaction(function () use ($producto, $imagen) {
            $foto = $producto->imagenes()->lockForUpdate()->findOrFail($imagen);
            $eraPortada = $foto->es_principal;
            $url = $foto->url;
            $foto->delete();
            if ($eraPortada) {
                $producto->imagenes()->orderBy('orden')->orderBy('id')->first()?->update(['es_principal' => true]);
            }
            DB::afterCommit(fn () => Archivos::borrarPublico($url));
        });

        return new MiProductoResource($this->cargar($producto));
    }

    /** POST /{producto}/fotos/{imagen}/portada — esa foto pasa a ser la portada. */
    public function portada(Negocio $negocio, Producto $producto, int $imagen): MiProductoResource
    {
        DB::transaction(function () use ($producto, $imagen) {
            $nueva = $producto->imagenes()->lockForUpdate()->findOrFail($imagen);
            // Una sola portada por producto (uq_producto_imagen_principal): primero se quita la otra.
            $producto->imagenes()->where('id', '!=', $nueva->id)->where('es_principal', true)->update(['es_principal' => false]);
            $nueva->update(['es_principal' => true]);
        });

        return new MiProductoResource($this->cargar($producto));
    }

    /** PATCH /{producto}/disponible — mostrar u ocultar en el catálogo, sin editar lo demás. */
    public function disponible(Request $request, Negocio $negocio, Producto $producto): MiProductoResource
    {
        $producto->update($request->validate(['disponible' => ['required', 'boolean']]));

        return new MiProductoResource($this->cargar($producto));
    }

    /**
     * PATCH /{producto}/stock — "Renovar stock": cuántas unidades hay ahora,
     * sin editar lo demás (ej. cuando se agotó y llegó mercadería).
     */
    public function stock(Request $request, Negocio $negocio, Producto $producto): MiProductoResource
    {
        $producto->update($request->validate(
            ['stock' => ['required', 'integer', 'min:0', 'max:100000']],
            ['stock.required' => 'Escribe cuántas unidades tienes ahora.'],
        ));

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

    /**
     * Agrega fotos extra (no portada; si no tenía ninguna, la primera lo es).
     * 422 si con estas pasaría de ProductoImagen::MAXIMO.
     *
     * @param  UploadedFile[]  $fotos
     */
    private function agregarFotos(Producto $producto, array $fotos): void
    {
        if ($fotos === []) {
            return;
        }
        $actuales = $producto->imagenes()->count();
        if ($actuales + count($fotos) > ProductoImagen::MAXIMO) {
            throw ValidationException::withMessages(['fotos' => 'Un producto puede tener hasta '.ProductoImagen::MAXIMO
                ." fotos. Ya tiene $actuales: borra alguna para agregar otra."]);
        }
        $orden = (int) $producto->imagenes()->max('orden');
        foreach (array_values($fotos) as $i => $foto) {
            $producto->imagenes()->create([
                'url' => Archivos::guardarPublico($foto, 'productos'),
                'es_principal' => $actuales === 0 && $i === 0,
                'orden' => $orden + $i + 1,
            ]);
        }
    }

    private function cargar(Producto $producto): Producto
    {
        return $producto->refresh()->load(['categoria', 'imagenPrincipal', 'imagenes']);
    }
}
