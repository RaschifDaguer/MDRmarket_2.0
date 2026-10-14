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
}
