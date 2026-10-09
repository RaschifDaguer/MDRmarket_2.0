<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Guarda los archivos que suben los usuarios en el disco configurado
 * (ver config/filesystems.php: media_disk y privado_disk). Para pasar a la
 * nube solo hay que cambiar MEDIA_DISK en el .env; el resto del código no cambia.
 */
class Archivos
{
    /**
     * Foto pública (negocio, producto). Devuelve lo que se guarda en la base:
     * - disco local: solo la ruta (ej. "negocios/abc.png"); la URL completa se
     *   arma al responder con url(), según desde dónde pregunten
     *   (localhost, emulador 10.0.2.2 o internet);
     * - disco en la nube: la URL completa que da el servicio.
     */
    public static function guardarPublico(UploadedFile $archivo, string $carpeta): string
    {
        $disco = config('filesystems.media_disk');
        $ruta = $archivo->store($carpeta, $disco);

        return $disco === 'public' ? $ruta : Storage::disk($disco)->url($ruta);
    }

    /** URL para mostrar una foto guardada con guardarPublico() (o una URL externa). */
    public static function url(?string $valor): ?string
    {
        if ($valor === null || $valor === '') {
            return null;
        }
        if (Str::startsWith($valor, ['http://', 'https://'])) {
            return $valor;
        }

        // El disco local se sirve por una ruta de la API (con CORS, para que
        // Flutter web pueda dibujar la imagen).
        return route('archivos.ver', ['ruta' => $valor]);
    }

    /** Documento privado (carnet, licencia, RUAT). Devuelve la ruta interna. */
    public static function guardarPrivado(UploadedFile $archivo, string $carpeta): string
    {
        return $archivo->store($carpeta, config('filesystems.privado_disk'));
    }

    public static function borrarPrivado(?string $ruta): void
    {
        if ($ruta) {
            Storage::disk(config('filesystems.privado_disk'))->delete($ruta);
        }
    }
}
