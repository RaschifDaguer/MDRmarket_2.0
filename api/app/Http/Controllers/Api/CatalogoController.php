<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoriaResource;
use App\Http\Resources\ProductoCatalogoResource;
use App\Http\Resources\ResenaResource;
use App\Http\Resources\TiendaResource;
use App\Models\Categoria;
use App\Models\Negocio;
use App\Models\ProductoImagen;
use App\Models\Resena;
use App\Support\Archivos;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

/** Lo que ve cualquier cliente: categorías, productos y tiendas (no pide sesión). */
class CatalogoController extends Controller
{
    /** GET /api/categorias — categorías principales con sus subcategorías. */
    public function categorias(): AnonymousResourceCollection
    {
        return CategoriaResource::collection(
            Categoria::principales()->with('subcategorias')->get()
        );
    }

    /**
     * GET /api/productos — catálogo con filtros, de 20 en 20.
     *   categoria (principal) · subcategoria · negocio · q (texto) · ofertas=1
     *   orden: populares (por defecto) | recientes | precio | precio_desc | rating
     */
    public function productos(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'categoria' => ['nullable', 'integer'],
            'subcategoria' => ['nullable', 'integer'],
            'negocio' => ['nullable', 'integer'],
            'q' => ['nullable', 'string', 'max:100'],
            'ofertas' => ['nullable', 'boolean'],
            'orden' => ['nullable', 'in:populares,recientes,precio,precio_desc,rating'],
        ]);

        $consulta = DB::table('v_catalogo_producto')
            ->when($filtros['categoria'] ?? null, fn ($q, $id) => $q->where('categoria_principal_id', $id))
            ->when($filtros['subcategoria'] ?? null, fn ($q, $id) => $q->where('categoria_id', $id))
            ->when($filtros['negocio'] ?? null, fn ($q, $id) => $q->where('negocio_id', $id))
            ->when($request->boolean('ofertas'), fn ($q) => $q->where('en_oferta', 1))
            ->when($filtros['q'] ?? null, function ($q, $texto) {
                $like = '%'.addcslashes($texto, '%_\\').'%';
                $q->where(fn ($q) => $q->where('nombre', 'like', $like)
                    ->orWhere('descripcion', 'like', $like)
                    ->orWhere('negocio', 'like', $like)
                    ->orWhere('categoria', 'like', $like));
            });

        match ($filtros['orden'] ?? 'populares') {
            'recientes' => $consulta->orderByDesc('id'),
            'precio' => $consulta->orderBy('precio_final'),
            'precio_desc' => $consulta->orderByDesc('precio_final'),
            'rating' => $consulta->orderByRaw('rating_promedio IS NULL, rating_promedio DESC'),
            default => $consulta->orderByDesc('negocio_abierto')->orderByDesc('total_vendidos')->orderByDesc('id'),
        };

        return ProductoCatalogoResource::collection($consulta->paginate(20)->withQueryString());
    }

    /** GET /api/productos/{id} — detalle con todas sus fotos y las últimas reseñas. */
    public function producto(int $id): JsonResponse
    {
        $fila = DB::table('v_catalogo_producto')->where('id', $id)->first()
            ?? abort(404, 'Este producto ya no está disponible.');

        $negocio = Negocio::find($fila->negocio_id);

        return response()->json([
            ...(new ProductoCatalogoResource($fila))->resolve(),
            'imagenes' => ProductoImagen::where('producto_id', $id)
                ->orderByDesc('es_principal')->orderBy('orden')
                ->pluck('url')->map(fn ($url) => Archivos::url($url)),
            'negocio' => [
                ...(new ProductoCatalogoResource($fila))->resolve()['negocio'],
                'tiempo_preparacion_min' => $negocio->tiempo_preparacion_min,
                'pedido_minimo' => $negocio->pedido_minimo,
            ],
            'resenas' => ResenaResource::collection(
                Resena::with('autor')->where('tipo', 'producto')->where('producto_id', $id)
                    ->where('visible', true)->latest('updated_at')->limit(20)->get()
            ),
        ]);
    }

    /** GET /api/tiendas — negocios aprobados (filtros: categoria, q), de 20 en 20. */
    public function tiendas(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'categoria' => ['nullable', 'integer'],
            'q' => ['nullable', 'string', 'max:100'],
        ]);

        $tiendas = $this->tiendasVisibles()
            ->with('categoria')
            ->withCount(['productos' => fn ($q) => $q->where('disponible', true)])
            ->when($filtros['categoria'] ?? null, fn ($q, $id) => $q->where('categoria_id', $id))
            ->when($filtros['q'] ?? null, fn ($q, $texto) => $q->where('nombre', 'like', '%'.addcslashes($texto, '%_\\').'%'))
            ->orderByDesc('abierto')
            ->orderByRaw('rating_promedio IS NULL, rating_promedio DESC')
            ->orderBy('nombre')
            ->paginate(20)
            ->withQueryString();

        return TiendaResource::collection($tiendas);
    }

    /** GET /api/tiendas/{id} — página del negocio: datos, horario, productos y reseñas. */
    public function tienda(int $id): JsonResponse
    {
        $tienda = $this->tiendasVisibles()->with(['categoria', 'horarios'])->find($id)
            ?? abort(404, 'Este negocio no está disponible.');

        $productos = DB::table('v_catalogo_producto')->where('negocio_id', $id)
            ->orderBy('categoria')->orderBy('nombre')->get();

        return response()->json([
            ...(new TiendaResource($tienda))->resolve(),
            'productos' => ProductoCatalogoResource::collection($productos),
            'resenas' => ResenaResource::collection(
                Resena::with('autor')->where('tipo', 'negocio')->where('negocio_id', $id)
                    ->where('visible', true)->latest('updated_at')->limit(20)->get()
            ),
        ]);
    }

    /** Aprobados y sin sanción vigente (la misma regla que el catálogo). */
    private function tiendasVisibles(): Builder
    {
        return Negocio::query()
            ->where('estado_verificacion', 'aprobado')
            ->whereRaw('fn_negocio_sancionado(negocio.id) = 0');
    }
}
