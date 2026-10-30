<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Moto, bicicleta, auto, camioneta o camión. Dice qué se le pide al vehículo:
 * placa, RUAT y licencia de conducir (la bicicleta no pide ninguno).
 */
class TipoVehiculo extends Model
{
    protected $table = 'tipo_vehiculo';

    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'requiere_placa' => 'boolean',
            'requiere_ruat' => 'boolean',
            'requiere_licencia' => 'boolean',
        ];
    }

    public function categoria(): BelongsTo
    {
        return $this->belongsTo(CategoriaVehiculo::class, 'categoria_vehiculo_id');
    }
}
