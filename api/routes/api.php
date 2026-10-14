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
use Illuminate\Support\Facades\Route;

// ---------- Cuenta ----------
Route::prefix('auth')->group(function () {
    Route::post('registro', [AuthController::class, 'registro'])->middleware('throttle:10,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
});

// ---------- Públicas: catálogo ----------
Route::get('categorias', [CatalogoController::class, 'categorias']);
Route::get('productos', [CatalogoController::class, 'productos']);
Route::get('productos/{id}', [CatalogoController::class, 'producto'])->whereNumber('id');
Route::get('tiendas', [CatalogoController::class, 'tiendas']);
Route::get('tiendas/{id}', [CatalogoController::class, 'tienda'])->whereNumber('id');
Route::get('archivos/{ruta}', [ArchivoController::class, 'ver'])->where('ruta', '.*')->name('archivos.ver');

// ---------- Rutas que requieren sesión ----------
Route::middleware('auth:sanctum')->group(function () {
    Route::get('me', [AuthController::class, 'me']);
    Route::put('me', [PerfilController::class, 'actualizar']);
    Route::put('me/vista', [AuthController::class, 'cambiarVista']);
    Route::get('me/faltantes/{rol}', [PerfilController::class, 'faltantes']);

    // Documentos (carnet, licencia, RUAT, NIT…)
    Route::get('documentos', [DocumentoController::class, 'index']);
    Route::post('documentos', [DocumentoController::class, 'store']);

    // ----- Cliente -----
    Route::apiResource('direcciones', DireccionController::class)
        ->parameters(['direcciones' => 'direccion'])->except('show');
    Route::post('envio/cotizar', [PedidoController::class, 'cotizar']);
    Route::get('pedidos', [PedidoController::class, 'index']);
    Route::post('pedidos', [PedidoController::class, 'store'])->middleware('throttle:20,1');
    Route::get('pedidos/{pedido}', [PedidoController::class, 'show']);
    Route::post('pedidos/{pedido}/cancelar', [PedidoController::class, 'cancelar']);
    Route::put('resenas', [ResenaController::class, 'guardar']);

    // ----- Comerciante -----
    Route::get('negocios', [NegocioController::class, 'index']);
    Route::post('negocios', [NegocioController::class, 'store']);

    // Todo lo de un negocio: solo su dueño (si no, 404).
    Route::prefix('negocios/{negocio}')->middleware('dueno.negocio')->scopeBindings()->group(function () {
        Route::post('/', [NegocioController::class, 'update']);
        Route::patch('abierto', [NegocioController::class, 'abierto']);
        Route::put('horario', [NegocioController::class, 'horario']);
        Route::get('resumen', [Comerciante\ReporteController::class, 'resumen']);
        Route::get('reporte', [Comerciante\ReporteController::class, 'reporte']);
        Route::get('reporte-productos', [Comerciante\ReporteController::class, 'productos']);

        Route::get('productos', [Comerciante\ProductoController::class, 'index']);
        Route::post('productos', [Comerciante\ProductoController::class, 'store']);
        // POST para editar: lleva la foto (multipart).
        Route::post('productos/{producto}', [Comerciante\ProductoController::class, 'update']);
        Route::patch('productos/{producto}/disponible', [Comerciante\ProductoController::class, 'disponible']);
        Route::delete('productos/{producto}', [Comerciante\ProductoController::class, 'destroy']);

        Route::get('pedidos', [Comerciante\PedidoController::class, 'index']);
        Route::get('pedidos/{pedido}', [Comerciante\PedidoController::class, 'show']);
        Route::put('pedidos/{pedido}/estado', [Comerciante\PedidoController::class, 'estado']);

        Route::get('registros', [Comerciante\RegistroController::class, 'index']);
        Route::post('registros', [Comerciante\RegistroController::class, 'store']);
        Route::delete('registros/{registro}', [Comerciante\RegistroController::class, 'destroy']);

        Route::get('resenas', [Comerciante\ResenaController::class, 'index']);
        Route::put('resenas/{resena}/respuesta', [Comerciante\ResenaController::class, 'responder'])->withoutScopedBindings();
    });
});
