<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

// ---------- Cuenta ----------
Route::prefix('auth')->group(function () {
    Route::post('registro', [AuthController::class, 'registro'])->middleware('throttle:10,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
});

// ---------- Rutas que requieren sesión ----------
Route::middleware('auth:sanctum')->group(function () {
    Route::get('me', [AuthController::class, 'me']);
    Route::put('me/vista', [AuthController::class, 'cambiarVista']);
});
