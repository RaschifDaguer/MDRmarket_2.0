<?php

use App\Http\Controllers\Api\ArchivoController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CatalogoController;
use App\Http\Controllers\Api\Comerciante;
use App\Http\Controllers\Api\DireccionController;
use App\Http\Controllers\Api\DocumentoController;
use App\Http\Controllers\Api\NegocioController;
use App\Http\Controllers\Api\PedidoController;
use App\Http\Controllers\Api\PerfilController;
use App\Http\Controllers\Api\ResenaController;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// Límites de solicitudes por minuto (ver AppServiceProvider::limitesDeSolicitudes):
// toda la API tiene el general ("api"); además, login, registro, pedidos,
// cambios de datos ("escritura") y subida de fotos ("subidas") tienen el suyo.
// Ver fotos ("archivos") tiene uno propio, más alto, en vez del general.

// ---------- Estado del servidor (GET /api) ----------
// Para comprobar de un vistazo que la API y la base de datos funcionan.
Route::get('/', function () {
    try {
        DB::connection()->getPdo();
        $base = 'conectada';
    } catch (Throwable) {
        $base = 'sin conexión (la base de datos está apagada o no responde)';
    }

    // ¿storage/app es otro disco (el Volume de Railway)? Si es el mismo que el
    // resto del contenedor, las fotos se pierden en cada despliegue.
    $disco = @stat(storage_path('app'));
    $contenedor = @stat(storage_path());
    $permanente = $disco && $contenedor && $disco['dev'] !== $contenedor['dev'];

    return response()->json([
        'nombre' => 'API de MDR Market',
        'estado' => 'en línea',
        'base_de_datos' => $base,
        'fotos' => match (true) {
            $permanente => 'disco permanente',
            app()->environment('production') => 'disco temporal (se borran al desplegar)',
            default => 'disco local',
        },
        'documentacion' => url('/docs/api'),
        'panel_admin' => url('/admin'),
    ]);
});

// ---------- Cuenta ----------
Route::prefix('auth')->group(function () {
    Route::post('registro', [AuthController::class, 'registro'])->middleware('throttle:registro');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
});

// ---------- Públicas: catálogo ----------
Route::get('categorias', [CatalogoController::class, 'categorias']);
Route::get('productos', [CatalogoController::class, 'productos']);
Route::get('productos/{id}', [CatalogoController::class, 'producto'])->whereNumber('id');
Route::get('tiendas', [CatalogoController::class, 'tiendas']);
Route::get('tiendas/{id}', [CatalogoController::class, 'tienda'])->whereNumber('id');
// Fotos: un catálogo carga muchas a la vez, así que tienen su propio límite
// (más alto) y no gastan el general de la API.
Route::get('archivos/{ruta}', [ArchivoController::class, 'ver'])
    ->where('ruta', '.*')
    ->withoutMiddleware('throttle:api')
    ->middleware('throttle:archivos')
    ->name('archivos.ver');

// ---------- Rutas que requieren sesión ----------
Route::middleware('auth:sanctum')->group(function () {
    Route::get('me', [AuthController::class, 'me']);
    Route::get('me/faltantes/{rol}', [PerfilController::class, 'faltantes']);
    Route::get('documentos', [DocumentoController::class, 'index']);
    Route::get('direcciones', [DireccionController::class, 'index']);
    Route::get('pedidos', [PedidoController::class, 'index']);
    Route::get('pedidos/{pedido}', [PedidoController::class, 'show']);
    Route::get('negocios', [NegocioController::class, 'index']);

    // Hacer un pedido: límite propio (evita pedidos falsos en masa).
    Route::post('pedidos', [PedidoController::class, 'store'])->middleware('throttle:pedidos');

    // Subir fotos.
    Route::middleware('throttle:subidas')->group(function () {
        Route::post('documentos', [DocumentoController::class, 'store']);
        Route::post('negocios', [NegocioController::class, 'store']);
    });

    // Guardar o cambiar datos.
    Route::middleware('throttle:escritura')->group(function () {
        Route::put('me', [PerfilController::class, 'actualizar']);
        Route::put('me/vista', [AuthController::class, 'cambiarVista']);
        Route::post('direcciones', [DireccionController::class, 'store']);
        Route::match(['put', 'patch'], 'direcciones/{direccion}', [DireccionController::class, 'update']);
        Route::delete('direcciones/{direccion}', [DireccionController::class, 'destroy']);
        Route::post('envio/cotizar', [PedidoController::class, 'cotizar']);
        Route::post('pedidos/{pedido}/cancelar', [PedidoController::class, 'cancelar']);
        Route::put('resenas', [ResenaController::class, 'guardar']);
    });

    // ----- Todo lo de un negocio: solo su dueño (si no, 404) -----
    Route::prefix('negocios/{negocio}')->middleware('dueno.negocio')->scopeBindings()->group(function () {
        Route::get('resumen', [Comerciante\ReporteController::class, 'resumen']);
        Route::get('reporte', [Comerciante\ReporteController::class, 'reporte']);
        Route::get('reporte-productos', [Comerciante\ReporteController::class, 'productos']);
        Route::get('productos', [Comerciante\ProductoController::class, 'index']);
        Route::get('pedidos', [Comerciante\PedidoController::class, 'index']);
        Route::get('pedidos/{pedido}', [Comerciante\PedidoController::class, 'show']);
        Route::get('registros', [Comerciante\RegistroController::class, 'index']);
        Route::get('resenas', [Comerciante\ResenaController::class, 'index']);

        // Con foto (multipart). POST también para editar.
        Route::middleware('throttle:subidas')->group(function () {
            Route::post('/', [NegocioController::class, 'update']);
            Route::post('productos', [Comerciante\ProductoController::class, 'store']);
            Route::post('productos/{producto}', [Comerciante\ProductoController::class, 'update']);
        });

        Route::middleware('throttle:escritura')->group(function () {
            Route::patch('abierto', [NegocioController::class, 'abierto']);
            Route::put('horario', [NegocioController::class, 'horario']);
            Route::patch('productos/{producto}/disponible', [Comerciante\ProductoController::class, 'disponible']);
            Route::delete('productos/{producto}', [Comerciante\ProductoController::class, 'destroy']);
            Route::put('pedidos/{pedido}/estado', [Comerciante\PedidoController::class, 'estado']);
            Route::post('registros', [Comerciante\RegistroController::class, 'store']);
            Route::delete('registros/{registro}', [Comerciante\RegistroController::class, 'destroy']);
            Route::put('resenas/{resena}/respuesta', [Comerciante\ResenaController::class, 'responder'])->withoutScopedBindings();
        });
    });
});
