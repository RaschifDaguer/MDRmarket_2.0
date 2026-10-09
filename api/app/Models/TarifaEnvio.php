<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Precio del envío: "hasta km_hasta cuesta precio" por categoría de vehículo. */
class TarifaEnvio extends Model
{
    protected $table = 'tarifa_envio';

    protected $fillable = ['categoria_vehiculo_id', 'km_hasta', 'precio', 'activo'];

    protected function casts(): array
    {
        return [
            'km_hasta' => 'decimal:2',
            'precio' => 'decimal:2',
            'activo' => 'boolean',
        ];
    }

    public function categoriaVehiculo(): BelongsTo
    {
        return $this->belongsTo(CategoriaVehiculo::class);
    }
}
