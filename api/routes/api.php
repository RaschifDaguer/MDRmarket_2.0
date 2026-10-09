<?php

use App\Http\Controllers\Api\ArchivoController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CatalogoController;
use App\Http\Controllers\Api\DocumentoController;
use App\Http\Controllers\Api\NegocioController;
use App\Http\Controllers\Api\PerfilController;
use Illuminate\Support\Facades\Route;

// ---------- Cuenta ----------
Route::prefix('auth')->group(function () {
    Route::post('registro', [AuthController::class, 'registro'])->middleware('throttle:10,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
});

// ---------- Públicas ----------
Route::get('categorias', [CatalogoController::class, 'categorias']);
Route::get('archivos/{ruta}', [ArchivoController::class, 'ver'])->where('ruta', '.*')->name('archivos.ver');

// ---------- Rutas que requieren sesión ----------
Route::middleware('auth:sanctum')->group(function () {
    Route::get('me', [AuthController::class, 'me']);
    Route::put('me', [PerfilController::class, 'actualizar']);
    Route::put('me/vista', [AuthController::class, 'cambiarVista']);
    Route::get('me/faltantes/{rol}', [PerfilController::class, 'faltantes']);

    // Comerciante
    Route::get('negocios', [NegocioController::class, 'index']);
    Route::post('negocios', [NegocioController::class, 'store']);

    // Documentos (carnet, licencia, RUAT, NIT…)
    Route::get('documentos', [DocumentoController::class, 'index']);
    Route::post('documentos', [DocumentoController::class, 'store']);
});
