<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/** Vehículo de un repartidor. Lo aprueba un administrador (estado_verificacion). */
class Vehiculo extends Model
{
    use SoftDeletes;

    protected $table = 'vehiculo';

    protected $fillable = [
        'tipo_vehiculo_id',
        'placa',
        'ruat',
        'marca',
        'modelo',
        'color',
        'anio',
        'en_uso',
    ];

    protected function casts(): array
    {
        return [
            'anio' => 'integer',
            'en_uso' => 'boolean',
        ];
    }

    public function repartidor(): BelongsTo
    {
        return $this->belongsTo(Repartidor::class, 'repartidor_id', 'usuario_id');
    }

    public function tipo(): BelongsTo
    {
        return $this->belongsTo(TipoVehiculo::class, 'tipo_vehiculo_id');
    }

    /** Fotos del vehículo, de la placa y del RUAT. */
    public function documentos(): HasMany
    {
        return $this->hasMany(Documento::class);
    }
}
