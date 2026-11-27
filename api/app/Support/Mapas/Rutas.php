<?php

namespace App\Support\Mapas;

use App\Http\Controllers\Api\RastreoController;
use App\Models\Configuracion;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Ruta por las calles entre 2 a 4 puntos (repartidor → tienda → casa), con
 * las indicaciones paso a paso en español. La calcula OSRM con los mapas de
 * OpenStreetMap: el servidor público de FOSSGIS (gratis, sin clave; pide
 * identificarse y un uso moderado). Se guarda 10 minutos en caché: el
 * repartidor y el cliente que siguen el mismo pedido la comparten.
 *
 * El tiempo de OSRM es "con calles libres": se estira hasta la velocidad
 * promedio de `configuracion` (25 km/h en moto, la misma del seguimiento).
 */
class Rutas
{
    public const MINUTOS_CACHE = 10;

    /** Bicicleta usa su perfil (ciclovías, sin autopistas); moto y auto, el de auto. */
    private const PERFILES = ['bicicleta' => 'routed-bike', 'moto' => 'routed-car', 'auto' => 'routed-car'];

    /**
     * @param  array<int, array{0: float, 1: float}>  $puntos  [latitud, longitud]
     * @return array<string, mixed>|null null si el servicio de rutas no respondió
     */
    public static function calcular(array $puntos, string $vehiculo = 'moto'): ?array
    {
        $perfil = self::PERFILES[$vehiculo] ?? self::PERFILES['moto'];
        // Redondeado a ~10 m: dos consultas casi desde el mismo lugar usan la misma ruta.
        $clave = 'ruta:'.$perfil.':'.implode(';', array_map(fn ($p) => round($p[0], 4).','.round($p[1], 4), $puntos));
        if ($guardada = Cache::get($clave)) {
            return $guardada;
        }

        $coordenadas = implode(';', array_map(fn ($p) => $p[1].','.$p[0], $puntos)); // OSRM: longitud,latitud
        try {
            $respuesta = Http::timeout(8)->connectTimeout(4)->retry(2, 300, throw: false)
                ->withUserAgent(config('services.mapas.agente'))
                ->acceptJson()
                ->get(rtrim(config('services.mapas.rutas_url'), '/')."/{$perfil}/route/v1/driving/{$coordenadas}", [
                    'overview' => 'false',
                    'steps' => 'true',
                    'geometries' => 'geojson',
                ]);
        } catch (Throwable $e) {
            Log::warning('Rutas: el servicio no respondió', ['error' => $e->getMessage()]);

            return null;
        }
        if (! $respuesta->successful() || $respuesta->json('code') !== 'Ok' || ! $respuesta->json('routes.0')) {
            Log::warning('Rutas: respuesta inválida', ['estado' => $respuesta->status(), 'codigo' => $respuesta->json('code')]);

            return null;
        }

        $ruta = self::armar($respuesta->json('routes.0'));
        Cache::put($clave, $ruta, now()->addMinutes(self::MINUTOS_CACHE));

        return $ruta;
    }

    /** Une la línea de cada paso en una sola y anota en qué punto empieza cada paso y termina cada tramo. */
    private static function armar(array $ruta): array
    {
        $puntos = [];
        $pasos = [];
        $tramos = [];
        $distancia = (float) $ruta['distance'];
        $duracion = max(1.0, (float) $ruta['duration']);
        $velocidad = (float) Configuracion::valor('velocidad_promedio_kmh', RastreoController::VELOCIDAD_KMH);
        // Si OSRM promete ir más rápido que la velocidad promedio, se usa la promedio.
        $factor = max(1.0, ($distancia / 1000 / max($velocidad, 1) * 3600) / $duracion);

        foreach ($ruta['legs'] ?? [] as $t => $tramo) {
            foreach ($tramo['steps'] ?? [] as $paso) {
                $linea = $paso['geometry']['coordinates'] ?? [];
                // La maniobra es el primer punto del paso: el último que ya está (si coincide) o el siguiente.
                $primero = isset($linea[0]) ? [round($linea[0][1], 6), round($linea[0][0], 6)] : null;
                $indicePaso = $puntos && end($puntos) === $primero ? count($puntos) - 1 : count($puntos);
                foreach ($linea as [$lng, $lat]) {
                    $punto = [round($lat, 6), round($lng, 6)];
                    if ($puntos && end($puntos) === $punto) {
                        continue; // el primero de un paso es el último del anterior
                    }
                    $puntos[] = $punto;
                }
                $maniobra = $paso['maneuver'] ?? [];
                [$lng, $lat] = $maniobra['location'] ?? ($linea[0] ?? [0, 0]);
                $pasos[] = [
                    'instruccion' => InstruccionesRuta::texto(
                        (string) ($maniobra['type'] ?? 'turn'),
                        $maniobra['modifier'] ?? null,
                        $paso['name'] ?? null,
                        isset($maniobra['exit']) ? (int) $maniobra['exit'] : null,
                    ),
                    'tipo' => $maniobra['type'] ?? 'turn',
                    'modificador' => $maniobra['modifier'] ?? null,
                    'calle' => trim((string) ($paso['name'] ?? '')) ?: null,
                    'distancia_m' => round((float) ($paso['distance'] ?? 0), 1),
                    'duracion_s' => round((float) ($paso['duration'] ?? 0) * $factor, 1),
                    'latitud' => round($lat, 6),
                    'longitud' => round($lng, 6),
                    // Dónde empieza en "puntos" (la maniobra), para saber cuál sigue.
                    'indice' => min($indicePaso, max(0, count($puntos) - 1)),
                    'tramo' => $t,
                ];
            }
            $tramos[] = [
                'distancia_m' => round((float) ($tramo['distance'] ?? 0), 1),
                'duracion_s' => round((float) ($tramo['duration'] ?? 0) * $factor, 1),
                'indice_fin' => max(0, count($puntos) - 1),
            ];
        }

        return [
            'distancia_m' => round($distancia, 1),
            'duracion_s' => round($duracion * $factor, 1),
            'puntos' => $puntos,
            'pasos' => $pasos,
            'tramos' => $tramos,
            'fuente' => 'OpenStreetMap',
        ];
    }
}
