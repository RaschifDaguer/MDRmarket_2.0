<?php

use App\Http\Controllers\Admin\DocumentoArchivoController;
use App\Http\Controllers\PagoQrController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// El panel de administración vive en /admin (Filament, ver AdminPanelProvider).
// "login" es a donde Laravel manda a quien no tiene sesión: al ingreso del panel.
Route::redirect('login', '/admin/login')->name('login');
// Fotos privadas de documentos: solo para administradores con sesión abierta.
Route::get('panel/documentos/{documento}/archivo', DocumentoArchivoController::class)
    ->name('panel.documento.archivo');

// Pasarela de pago de PRUEBA: la abre el QR de un pedido (ver App\Support\CobroQr).
Route::middleware('throttle:escritura')->group(function () {
    Route::get('pago-qr/{referencia}', [PagoQrController::class, 'ver'])->name('pago-qr.ver');
    Route::post('pago-qr/{referencia}', [PagoQrController::class, 'pagar'])->name('pago-qr.pagar');
});
