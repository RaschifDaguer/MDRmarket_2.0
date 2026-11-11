<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\Mime\MimeTypes;

/**
 * Guarda los archivos que suben los usuarios en el disco configurado
 * (ver config/filesystems.php: media_disk y privado_disk). Para pasar a la
 * nube solo hay que cambiar MEDIA_DISK en el .env; el resto del código no cambia.
 */
class Archivos
{
    /**
     * Formatos multimedia que se aceptan y que se pueden ver por /api/archivos.
     * Es una lista cerrada a propósito: nada de HTML, SVG ni programas, porque
     * un navegador podría ejecutarlos (y robar la sesión del panel).
     * Las extensiones son las que se deducen del CONTENIDO del archivo, no del
     * nombre que trae: por eso aparecen "mpga" (mp3), "oga" (ogg) o "qt" (mov).
     */
    public const FORMATOS = [
        'imagen' => ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'avif', 'bmp', 'tif', 'tiff'],
        'video' => ['mp4', 'm4v', 'mov', 'qt', 'webm', '3gp', '3g2', 'mkv', 'avi', 'mpeg', 'mpg'],
        'audio' => ['mp3', 'mpga', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'weba', 'amr', 'flac'],
        'documento' => ['pdf'],
    ];

    /** Todas las extensiones de FORMATOS (para la regla "mimes:"). */
    public static function extensiones(): array
    {
        return array_merge(...array_values(self::FORMATOS));
    }

    /** "imagen", "video", "audio" o "documento" según la extensión; null si no es multimedia. */
    public static function tipo(string $ruta): ?string
    {
        $extension = strtolower(pathinfo($ruta, PATHINFO_EXTENSION));
        foreach (self::FORMATOS as $tipo => $extensiones) {
            if (in_array($extension, $extensiones, true)) {
                return $tipo;
            }
        }

        return null;
    }

    /** Tipo MIME con el que se sirve un archivo, según su extensión (nunca uno ejecutable). */
    public static function tipoMime(string $ruta): string
    {
        $tipo = self::tipo($ruta);
        if ($tipo === null) {
            return 'application/octet-stream';
        }

        // De los tipos posibles, el de su familia (ej. .mp4 → video/mp4, no application/mp4).
        $familia = ['imagen' => 'image/', 'video' => 'video/', 'audio' => 'audio/', 'documento' => 'application/'][$tipo];
        $posibles = MimeTypes::getDefault()->getMimeTypes(strtolower(pathinfo($ruta, PATHINFO_EXTENSION)));
        foreach ($posibles as $mime) {
            if (str_starts_with($mime, $familia)) {
                return $mime;
            }
        }

        return $posibles[0] ?? 'application/octet-stream';
    }

    /**
     * Extensión con la que se guarda un archivo ya validado: la del nombre
     * original si corresponde a su contenido (así un .mp3 sigue siendo .mp3);
     * si no, la que se deduce del contenido.
     */
    public static function extensionSegura(UploadedFile $archivo): string
    {
        $original = strtolower($archivo->getClientOriginalExtension());
        $validas = MimeTypes::getDefault()->getExtensions((string) $archivo->getMimeType());

        return in_array($original, $validas, true) && self::tipo('x.'.$original) !== null
            ? $original
            : (string) $archivo->guessExtension();
    }

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

    /** Borra una foto pública del disco local (las URLs externas no se tocan). */
    public static function borrarPublico(?string $valor): void
    {
        if ($valor && ! Str::startsWith($valor, ['http://', 'https://'])) {
            Storage::disk('public')->delete($valor);
        }
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
