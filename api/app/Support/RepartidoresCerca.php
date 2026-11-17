<?php

namespace App\Support;

use App\Models\Configuracion;
use App\Models\Pedido;
use App\Models\Repartidor;

/**
 * "Buscando repartidor… 3 cerca de tu tienda": cuántos repartidores podrían
 * llevar un pedido listo. Cuentan los aprobados, en línea, sin sanción, con
 * un vehículo aprobado del tamaño que el pedido necesita (o más grande) y con
 * su ubicación de los últimos minutos dentro de `radio_busqueda_repartidor_km`
 * del negocio. No cuentan el comprador ni el dueño del negocio.
 */
class RepartidoresCerca
{
    /** Una ubicación más vieja que esto no cuenta (el repartidor pudo irse). */
    public const MINUTOS_UBICACION = 15;

    public static function contar(Pedido $pedido): int
    {
        $negocio = $pedido->negocio;
        if ($negocio?->latitud === null || $negocio->longitud === null) {
            return 0;
        }
        $radio = (float) Configuracion::valor('radio_busqueda_repartidor_km', 5);
        $nivel = (int) ($pedido->categoriaVehiculo?->nivel ?? 1);

        return Repartidor::query()
            ->where('estado_verificacion', 'aprobado')
            ->where('disponible', true)
            ->whereNotIn('usuario_id', [$pedido->comprador_id, $negocio->usuario_id])
            ->whereNotNull('latitud_actual')
            ->where('ubicacion_actualizada_en', '>=', now()->subMinutes(self::MINUTOS_UBICACION))
            ->whereRaw('fn_distancia_km(?, ?, latitud_actual, longitud_actual) <= ?', [$negocio->latitud, $negocio->longitud, $radio])
            ->whereRaw("fn_sancion_activa(usuario_id, 'repartidor') = 0")
            ->whereHas('vehiculos', fn ($v) => $v
                ->where('en_uso', true)
                ->where('estado_verificacion', 'aprobado')
                ->whereHas('tipo.categoria', fn ($c) => $c->where('nivel', '>=', $nivel)))
            ->count();
    }
}
