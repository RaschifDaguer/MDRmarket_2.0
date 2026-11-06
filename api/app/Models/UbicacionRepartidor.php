<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Un punto del GPS del repartidor mientras lleva un pedido (rastreo en el
 * mapa). La base borra los de más de `dias_historial_gps` días (evento
 * ev_limpiar_ubicaciones).
 */
class UbicacionRepartidor extends Model
{
    protected $table = 'ubicacion_repartidor';

    public $timestamps = false;

    protected $fillable = ['repartidor_id', 'pedido_id', 'latitud', 'longitud', 'registrado_en'];

    protected function casts(): array
    {
        return [
            'latitud' => 'float',
            'longitud' => 'float',
            'registrado_en' => 'datetime',
        ];
    }
}
