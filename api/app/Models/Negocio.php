<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
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

    public function productos(): HasMany
    {
        return $this->hasMany(Producto::class);
    }

    public function pedidos(): HasMany
    {
        return $this->hasMany(Pedido::class);
    }

    public function horarios(): HasMany
    {
        return $this->hasMany(NegocioHorario::class)->orderBy('dia_semana')->orderBy('hora_apertura');
    }

    public function registros(): HasMany
    {
        return $this->hasMany(RegistroComercio::class);
    }

    /** Solo los aprobados aparecen en el catálogo y reciben pedidos. */
    public function estaAprobado(): bool
    {
        return $this->estado_verificacion === 'aprobado';
    }
}
