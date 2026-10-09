<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ArchivoController extends Controller
{
    /**
     * GET /api/archivos/{ruta} — muestra una foto pública guardada en el disco
     * local (solo se usa mientras MEDIA_DISK=public). Pasa por la API para que
     * lleve cabeceras CORS y Flutter web pueda dibujarla.
     */
    public function ver(string $ruta): StreamedResponse
    {
        $disco = Storage::disk('public');
        abort_unless($disco->exists($ruta), 404);

        return $disco->response($ruta, null, ['Cache-Control' => 'public, max-age=604800']);
    }
}
