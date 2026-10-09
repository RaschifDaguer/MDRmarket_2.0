<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/** Negocio de un comerciante. Lo aprueba un administrador (estado_verificacion). */
class Negocio extends Model
{
    use SoftDeletes;

    protected $table = 'negocio';

    protected $fillable = [
        'usuario_id',
        'categoria_id',
        'nombre',
        'descripcion',
        'nit',
        'razon_social',
        'telefono',
        'direccion',
        'referencia',
        'latitud',
        'longitud',
        'logo_url',
        'banner_url',
        'tiempo_preparacion_min',
        'pedido_minimo',
        'abierto',
    ];

    protected function casts(): array
    {
        return [
            'latitud' => 'float',
            'longitud' => 'float',
            'abierto' => 'boolean',
            'pedido_minimo' => 'decimal:2',
            'rating_promedio' => 'float',
        ];
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(Usuario::class);
    }

    public function categoria(): BelongsTo
    {
        return $this->belongsTo(Categoria::class);
    }
}
