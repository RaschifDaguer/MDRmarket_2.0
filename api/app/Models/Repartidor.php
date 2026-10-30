<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Perfil de repartidor de un usuario (uno por persona: la clave es usuario_id).
 * Lo aprueba un administrador (estado_verificacion).
 */
class Repartidor extends Model
{
    protected $table = 'repartidor';

    protected $primaryKey = 'usuario_id';

    public $incrementing = false;

    protected $fillable = ['usuario_id'];

    protected function casts(): array
    {
        return [
            'disponible' => 'boolean',
            'latitud_actual' => 'float',
            'longitud_actual' => 'float',
            'rating_promedio' => 'float',
            'ubicacion_actualizada_en' => 'datetime',
            'verificado_en' => 'datetime',
        ];
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(Usuario::class);
    }

    public function vehiculos(): HasMany
    {
        return $this->hasMany(Vehiculo::class, 'repartidor_id', 'usuario_id');
    }

    public function estaAprobado(): bool
    {
        return $this->estado_verificacion === 'aprobado';
    }
}
