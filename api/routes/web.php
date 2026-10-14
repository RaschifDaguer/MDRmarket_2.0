<?php

use App\Http\Controllers\Admin\DocumentoArchivoController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// El panel de administración vive en /admin (Filament, ver AdminPanelProvider).
// Fotos privadas de documentos: solo para administradores con sesión abierta.
Route::get('panel/documentos/{documento}/archivo', DocumentoArchivoController::class)
    ->name('panel.documento.archivo');
