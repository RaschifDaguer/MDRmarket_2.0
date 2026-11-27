<?php

namespace App\Support\Mapas;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Throwable;

/**
 * Del punto marcado en el mapa a la dirección escrita ("Calle Libertad 123,
 * Equipetrol, Santa Cruz de la Sierra"), con Nominatim de OpenStreetMap
 * (gratis, sin clave). Su política de uso pide identificarse, no pasar de 1
 * consulta por segundo y guardar las respuestas: se guarda cada punto 30 días
 * y el servidor espera su turno si dos personas marcan a la vez.
 */
class Direcciones
{
    public const DIAS_CACHE = 30;

    /** @return array{calle: ?string, barrio: ?string, ciudad: ?string, corta: string, texto: string}|null */
    public static function buscar(float $latitud, float $longitud): ?array
    {
        // ~1 m: el mismo punto (o casi) no se vuelve a preguntar.
        $clave = 'direccion:'.round($latitud, 5).','.round($longitud, 5);
        if ($guardada = Cache::get($clave)) {
            return $guardada;
        }

        // Una consulta por segundo como máximo, para todo el servidor.
        for ($intento = 0; ! RateLimiter::attempt('nominatim', 1, fn () => true, 1); $intento++) {
            if ($intento >= 2) {
                return null;
            }
            usleep(600_000);
        }

        try {
            $respuesta = Http::timeout(8)->connectTimeout(4)
                ->withUserAgent(config('services.mapas.agente'))
                ->acceptJson()
                ->get(rtrim(config('services.mapas.direcciones_url'), '/').'/reverse', [
                    'format' => 'jsonv2',
                    'lat' => $latitud,
                    'lon' => $longitud,
                    'zoom' => 18,
                    'addressdetails' => 1,
                    'accept-language' => 'es',
                ]);
        } catch (Throwable $e) {
            Log::warning('Direcciones: el servicio no respondió', ['error' => $e->getMessage()]);

            return null;
        }
        if (! $respuesta->successful() || ! is_array($respuesta->json('address'))) {
            Log::warning('Direcciones: respuesta inválida', ['estado' => $respuesta->status()]);

            return null;
        }

        $direccion = self::armar($respuesta->json('address'), (string) $respuesta->json('display_name'));
        Cache::put($clave, $direccion, now()->addDays(self::DIAS_CACHE));

        return $direccion;
    }

    private static function armar(array $a, string $completa): array
    {
        $primero = function (array $claves) use ($a): ?string {
            foreach ($claves as $c) {
                if (! empty($a[$c])) {
                    return trim((string) $a[$c]);
                }
            }

            return null;
        };

        $via = $primero(['road', 'pedestrian', 'footway', 'path', 'residential']);
        $numero = $primero(['house_number']);
        $calle = $via ? trim($via.' '.($numero ?? '')) : $primero(['amenity', 'shop', 'building', 'leisure']);
        $barrio = $primero(['neighbourhood', 'suburb', 'quarter', 'hamlet', 'city_district']);
        $ciudad = $primero(['city', 'town', 'village', 'municipality', 'county']);

        $partes = array_values(array_unique(array_filter([$calle, $barrio])));
        // Sin calle ni barrio (ej. en medio de un parque): las 2 primeras partes del nombre completo.
        $corta = $partes ? implode(', ', $partes) : implode(', ', array_slice(array_map('trim', explode(',', $completa)), 0, 2));

        return [
            'calle' => $calle,
            'barrio' => $barrio,
            'ciudad' => $ciudad,
            'corta' => $corta,
            'texto' => implode(', ', array_values(array_unique(array_filter([$corta, $ciudad])))),
        ];
    }
}
