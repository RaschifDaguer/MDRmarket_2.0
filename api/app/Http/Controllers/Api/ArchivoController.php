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
        // Solo fotos, y sin salir de la carpeta (nada de "../../.env").
        abort_if(str_contains($ruta, '..') || str_contains($ruta, '\\'), 404);
        abort_unless(preg_match('/\.(jpe?g|png|webp|gif)$/i', $ruta), 404);

        $disco = Storage::disk('public');
        abort_unless($disco->exists($ruta), 404);

        return $disco->response($ruta, null, ['Cache-Control' => 'public, max-age=604800']);
    }
}
