<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Archivos;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Archivos multimedia de cada usuario: fotos, videos, audios y PDF.
 *
 * Se guardan en el disco de fotos públicas (media_disk), en una carpeta por
 * usuario (multimedia/u{id}). El nombre es aleatorio (40 letras y números):
 * nadie puede adivinar la dirección de un archivo ajeno. No usa tablas: la
 * carpeta es la lista, así que funciona igual en cualquier base.
 * Límites en config/filesystems.php (multimedia).
 */
class MultimediaController extends Controller
{
    /** GET /api/multimedia — mis archivos y cuánto espacio me queda. */
    public function index(Request $request): JsonResponse
    {
        $archivos = collect($this->disco()->files($this->carpeta($request)))
            ->filter(fn (string $ruta) => Archivos::tipo($ruta) !== null)
            ->map(fn (string $ruta) => $this->datos($ruta))
            ->sortByDesc('fecha')
            ->values();

        return response()->json([
            'data' => $archivos,
            'usado_mb' => round($archivos->sum('tamano_bytes') / 1048576, 1),
            'cuota_mb' => config('filesystems.multimedia.cuota_mb'),
            'max_mb' => config('filesystems.multimedia.max_mb'),
            'formatos' => Archivos::FORMATOS,
        ]);
    }

    /** POST /api/multimedia — subir un archivo (multipart, campo "archivo"). */
    public function store(Request $request): JsonResponse
    {
        $limites = config('filesystems.multimedia');
        $request->validate([
            'archivo' => ['required', 'file', 'mimes:'.implode(',', Archivos::extensiones()), 'max:'.($limites['max_mb'] * 1024)],
        ], [
            'archivo.mimes' => 'Ese formato no se acepta. Se pueden subir fotos, videos, audios y PDF.',
            'archivo.max' => "El archivo pesa más de {$limites['max_mb']} MB.",
        ]);

        $archivo = $request->file('archivo');
        $carpeta = $this->carpeta($request);
        $disco = $this->disco();

        $usado = collect($disco->files($carpeta))->sum(fn (string $ruta) => $disco->size($ruta));
        if ($usado + $archivo->getSize() > $limites['cuota_mb'] * 1048576) {
            throw ValidationException::withMessages([
                'archivo' => "Llegaste a tu límite de {$limites['cuota_mb']} MB. Borra algún archivo para subir otro.",
            ]);
        }

        // El disco del servidor es compartido: siempre queda una reserva libre.
        $libre = @disk_free_space(storage_path('app'));
        if ($libre !== false && $libre - $archivo->getSize() < $limites['reserva_mb'] * 1048576) {
            abort(507, 'El servidor no tiene espacio para más archivos. Avísale al administrador.');
        }

        $nombre = Str::random(40).'.'.Archivos::extensionSegura($archivo);
        $ruta = $archivo->storeAs($carpeta, $nombre, config('filesystems.media_disk'));
        abort_unless($ruta, 500, 'No se pudo guardar el archivo.');

        return response()->json(['data' => $this->datos($ruta)], 201);
    }

    /** DELETE /api/multimedia/{nombre} — borrar uno de mis archivos (ajeno o inexistente: 404). */
    public function destroy(Request $request, string $nombre): JsonResponse
    {
        abort_unless(preg_match('/^[A-Za-z0-9]{40}\.[a-z0-9]{2,5}$/', $nombre), 404);

        $ruta = $this->carpeta($request).'/'.$nombre;
        abort_unless($this->disco()->exists($ruta), 404);
        $this->disco()->delete($ruta);

        return response()->json(['message' => 'Archivo borrado.']);
    }

    private function disco(): Filesystem
    {
        return Storage::disk(config('filesystems.media_disk'));
    }

    private function carpeta(Request $request): string
    {
        return 'multimedia/u'.$request->user()->id;
    }

    private function datos(string $ruta): array
    {
        $disco = $this->disco();

        return [
            'nombre' => basename($ruta),
            'tipo' => Archivos::tipo($ruta),
            'url' => config('filesystems.media_disk') === 'public' ? Archivos::url($ruta) : $disco->url($ruta),
            'tamano_bytes' => $disco->size($ruta),
            'fecha' => date(DATE_ATOM, $disco->lastModified($ruta)),
        ];
    }
}
