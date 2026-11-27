<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Mapas\Direcciones;
use App\Support\Mapas\Rutas;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Lo que la app necesita de los mapas y no puede calcular sola: la ruta por
 * las calles (modo GPS del repartidor y seguimiento del cliente) y la
 * dirección escrita del punto que se marca. Pasan por la API (y no directo
 * desde el celular) para guardar las respuestas, respetar los límites de los
 * servicios gratis y poder cambiar de servicio sin volver a armar la app.
 */
class MapaController extends Controller
{
    /** Bolivia, con un margen: la API no calcula rutas para cualquier lugar del mundo. */
    private const LATITUD = [-23.5, -9.0];

    private const LONGITUD = [-70.0, -57.0];

    /**
     * GET /api/mapas/ruta?puntos=lat,lng;lat,lng[;…]&vehiculo=moto|bicicleta|auto
     *
     * De 2 a 4 puntos en orden (ej. repartidor → tienda → casa). Devuelve la
     * línea por las calles, la distancia, el tiempo y los pasos ("Gira a la
     * derecha hacia…"). 503 si el servicio de rutas no responde: la app dibuja
     * entonces una línea recta.
     */
    public function ruta(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'puntos' => ['required', 'string', 'max:200'],
            'vehiculo' => ['nullable', 'in:moto,bicicleta,auto'],
        ]);

        $puntos = [];
        foreach (explode(';', $datos['puntos']) as $texto) {
            $puntos[] = $this->punto($texto, 'puntos');
        }
        if (count($puntos) < 2 || count($puntos) > 4) {
            throw ValidationException::withMessages(['puntos' => 'La ruta lleva entre 2 y 4 puntos.']);
        }

        $ruta = Rutas::calcular($puntos, $datos['vehiculo'] ?? 'moto');

        return $ruta
            ? response()->json($ruta)
            : response()->json(['message' => 'No se pudo calcular la ruta por las calles. Intenta en unos segundos.'], 503);
    }

    /**
     * GET /api/mapas/direccion?latitud=…&longitud=…
     *
     * La dirección del punto marcado: calle (y número si lo hay), barrio y
     * ciudad. 503 si el servicio no responde: la app deja escribirla a mano.
     */
    public function direccion(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'latitud' => ['required', 'numeric', 'between:'.implode(',', self::LATITUD)],
            'longitud' => ['required', 'numeric', 'between:'.implode(',', self::LONGITUD)],
        ], [
            'latitud.between' => 'El punto está fuera de Bolivia.',
            'longitud.between' => 'El punto está fuera de Bolivia.',
        ]);

        $direccion = Direcciones::buscar((float) $datos['latitud'], (float) $datos['longitud']);

        return $direccion
            ? response()->json($direccion)
            : response()->json(['message' => 'No se pudo encontrar la dirección. Escríbela a mano.'], 503);
    }

    /** "lat,lng" → [lat, lng], dentro de Bolivia. */
    private function punto(string $texto, string $campo): array
    {
        $partes = explode(',', trim($texto));
        if (count($partes) !== 2 || ! is_numeric($partes[0]) || ! is_numeric($partes[1])) {
            throw ValidationException::withMessages([$campo => 'Cada punto va como "latitud,longitud".']);
        }
        [$lat, $lng] = [(float) $partes[0], (float) $partes[1]];
        if ($lat < self::LATITUD[0] || $lat > self::LATITUD[1] || $lng < self::LONGITUD[0] || $lng > self::LONGITUD[1]) {
            throw ValidationException::withMessages([$campo => 'El punto está fuera de Bolivia.']);
        }

        return [$lat, $lng];
    }
}
