<?php

namespace App\Support\Mapas;

/**
 * Convierte cada maniobra de OSRM (tipo + modificador + nombre de la calle)
 * en una indicación en español, como las de un GPS: "Gira a la derecha
 * hacia Av. Busch", "En la rotonda, toma la 2.ª salida".
 *
 * Tipos y modificadores: https://project-osrm.org/docs/v5.24.0/api/#stepmaneuver-object
 */
class InstruccionesRuta
{
    private const GIROS = [
        'uturn' => 'Da la vuelta en U',
        'sharp right' => 'Gira fuerte a la derecha',
        'right' => 'Gira a la derecha',
        'slight right' => 'Gira levemente a la derecha',
        'straight' => 'Sigue derecho',
        'slight left' => 'Gira levemente a la izquierda',
        'left' => 'Gira a la izquierda',
        'sharp left' => 'Gira fuerte a la izquierda',
    ];

    public static function texto(string $tipo, ?string $modificador, ?string $calle, ?int $salida = null): string
    {
        $calle = trim((string) $calle) ?: null;
        $hacia = $calle ? " hacia {$calle}" : '';
        $por = $calle ? " por {$calle}" : '';
        $lado = str_contains((string) $modificador, 'left') ? 'izquierda' : 'derecha';
        $giro = self::GIROS[$modificador ?? 'straight'] ?? 'Sigue derecho';

        return match ($tipo) {
            'depart' => 'Sal'.($calle ? " por {$calle}" : ' hacia tu destino'),
            'arrive' => 'Llegaste a tu destino',
            'new name' => 'Continúa'.($por ?: ' derecho'),
            'continue' => $modificador === null || $modificador === 'straight' ? 'Sigue derecho'.$por : $giro.$por,
            'merge' => 'Incorpórate'.($calle ? " a {$calle}" : ' al carril'),
            'on ramp' => 'Toma la entrada'.$hacia,
            'off ramp' => 'Toma la salida'.$hacia,
            'fork' => "En la bifurcación, mantente a la {$lado}".$hacia,
            'end of road' => "Al final de la calle, gira a la {$lado}".$hacia,
            'roundabout', 'rotary' => 'En la rotonda, toma la '.($salida ? "{$salida}.ª salida" : 'salida').$hacia,
            'exit roundabout', 'exit rotary' => 'Sal de la rotonda'.$por,
            // turn, roundabout turn, notification y cualquier tipo nuevo.
            default => $giro.($modificador === 'straight' || $modificador === 'uturn' ? $por : $hacia),
        };
    }
}
