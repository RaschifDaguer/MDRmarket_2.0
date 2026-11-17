<?php

namespace App\Support;

use App\Models\Configuracion;
use App\Models\Negocio;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Costo del envío entre un negocio y el cliente. Usa las funciones de la base:
 * fn_anillo (cobertura hasta el 10mo anillo) y fn_cotizar_envio (tarifas por
 * km). Mientras no se use Google Directions, los km por calle se estiman como
 * línea recta × factor_ruta (igual que hace fn_cotizar_envio sin km).
 */
class Envio
{
    public const FUERA_DE_COBERTURA = 'Esa ubicación está fuera de la zona de cobertura (del centro al 10mo anillo).';

    /** ¿En qué anillo está? null = fuera de cobertura. */
    public static function anillo(float $latitud, float $longitud): ?int
    {
        $anillo = DB::scalar('SELECT fn_anillo(?, ?)', [$latitud, $longitud]);

        return $anillo === null ? null : (int) $anillo;
    }

    /** Falla con un error en "latitud" si el punto está fuera de cobertura. */
    public static function exigirCobertura(float $latitud, float $longitud, string $campo = 'latitud'): int
    {
        return self::anillo($latitud, $longitud)
            ?? throw ValidationException::withMessages([$campo => self::FUERA_DE_COBERTURA]);
    }

    /**
     * @return array{costo_envio: string, distancia_km: float, anillo: int, tarifa_servicio: string}
     */
    public static function cotizar(Negocio $negocio, float $latitud, float $longitud, int $categoriaVehiculo = 1): array
    {
        $anillo = self::exigirCobertura($latitud, $longitud);

        $costo = DB::scalar('SELECT fn_cotizar_envio(?, ?, ?, ?, NULL, ?)', [
            $negocio->latitud, $negocio->longitud, $latitud, $longitud, $categoriaVehiculo,
        ]);
        // NULL también si la distancia supera la última tarifa (ej. más de 30 km).
        if ($costo === null) {
            throw ValidationException::withMessages(['latitud' => self::FUERA_DE_COBERTURA]);
        }

        $lineaRecta = (float) DB::scalar('SELECT fn_distancia_km(?, ?, ?, ?)', [
            $negocio->latitud, $negocio->longitud, $latitud, $longitud,
        ]);

        return [
            'costo_envio' => number_format((float) $costo, 2, '.', ''),
            'distancia_km' => round($lineaRecta * (float) Configuracion::valor('factor_ruta', 1.3), 2),
            'anillo' => $anillo,
            'tarifa_servicio' => number_format((float) Configuracion::valor('tarifa_servicio', 0), 2, '.', ''),
        ];
    }

    /** Si no hay valor en `configuracion`: velocidad media de reparto en la ciudad. */
    public const VELOCIDAD_KMH = 20;

    /** Minutos de preparación cuando el negocio no los cargó. */
    public const PREPARACION_MIN = 15;

    /**
     * Para listar tiendas: envío "desde" (vehículo liviano), distancia y
     * tiempo estimado, sin fallar. Fuera de cobertura: en_cobertura = false
     * y sin costo. $anilloCliente se calcula una vez para toda la lista.
     *
     * @return array{en_cobertura: bool, costo_envio: ?string, distancia_km: ?float, tiempo_min: ?int, tiempo_max: ?int}
     */
    public static function estimar(Negocio $negocio, float $latitud, float $longitud, ?int $anilloCliente): array
    {
        $sinCobertura = ['en_cobertura' => false, 'costo_envio' => null, 'distancia_km' => null, 'tiempo_min' => null, 'tiempo_max' => null];
        if ($anilloCliente === null || $negocio->latitud === null || $negocio->longitud === null) {
            return $sinCobertura;
        }

        $costo = DB::scalar('SELECT fn_cotizar_envio(?, ?, ?, ?, NULL, 1)', [$negocio->latitud, $negocio->longitud, $latitud, $longitud]);
        if ($costo === null) {
            return $sinCobertura;
        }
        $km = round((float) DB::scalar('SELECT fn_distancia_km(?, ?, ?, ?)', [$negocio->latitud, $negocio->longitud, $latitud, $longitud])
            * (float) Configuracion::valor('factor_ruta', 1.3), 2);

        // Preparación + trayecto; el rango ("15–25 min") da margen para encontrar repartidor.
        $velocidad = max(1, (float) Configuracion::valor('velocidad_reparto_kmh', self::VELOCIDAD_KMH));
        $minimo = (int) ($negocio->tiempo_preparacion_min ?? self::PREPARACION_MIN) + (int) ceil($km / $velocidad * 60);

        return [
            'en_cobertura' => true,
            'costo_envio' => number_format((float) $costo, 2, '.', ''),
            'distancia_km' => $km,
            'tiempo_min' => $minimo,
            'tiempo_max' => $minimo + 10,
        ];
    }
}
