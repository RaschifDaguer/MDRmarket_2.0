<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Archivos;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class ArchivoController extends Controller
{
    /**
     * GET /api/archivos/{ruta} — muestra una foto o archivo multimedia público
     * guardado en el disco local (solo se usa mientras MEDIA_DISK=public).
     * Pasa por la API para que lleve cabeceras CORS y Flutter web pueda dibujarla.
     */
    public function ver(string $ruta): BinaryFileResponse
    {
        // Solo multimedia (fotos, videos, audios, PDF), y sin salir de la
        // carpeta (nada de "../../.env").
        abort_if(str_contains($ruta, '..') || str_contains($ruta, '\\'), 404);
        abort_if(Archivos::tipo($ruta) === null, 404);

        $disco = Storage::disk('public');
        abort_unless($disco->exists($ruta), 404);

        // Responde por partes si se lo piden (cabecera Range): un video se
        // puede adelantar sin descargarlo entero. El tipo sale de la
        // extensión, que ya se validó al subirlo.
        return response()->file($disco->path($ruta), [
            'Content-Type' => Archivos::tipoMime($ruta),
            'Cache-Control' => 'public, max-age=604800',
        ]);
    }
}
