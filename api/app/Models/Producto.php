<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Producto de un negocio. Siempre va en una subcategoría (lo exige
 * trg_producto_bi). `stock` NULL = sin control de stock (comida al momento).
 * El stock lo descuenta la base al pedir y lo suma al registrar una compra.
 */
class Producto extends Model
{
    use SoftDeletes;

    protected $table = 'producto';

    protected $fillable = [
        'negocio_id',
        'categoria_id',
        'categoria_vehiculo_id',
        'nombre',
        'descripcion',
        'precio',
        'costo',
        'precio_oferta',
        'oferta_inicio',
        'oferta_fin',
        'stock',
        'disponible',
    ];

    protected function casts(): array
    {
        return [
            'precio' => 'decimal:2',
            'costo' => 'decimal:2',
            'precio_oferta' => 'decimal:2',
            'oferta_inicio' => 'datetime',
            'oferta_fin' => 'datetime',
            'stock' => 'integer',
            'disponible' => 'boolean',
            'rating_promedio' => 'float',
        ];
    }

    public function negocio(): BelongsTo
    {
        return $this->belongsTo(Negocio::class);
    }

    public function categoria(): BelongsTo
    {
        return $this->belongsTo(Categoria::class);
    }

    public function imagenes(): HasMany
    {
        return $this->hasMany(ProductoImagen::class)->orderByDesc('es_principal')->orderBy('orden');
    }

    public function imagenPrincipal(): HasOne
    {
        return $this->hasOne(ProductoImagen::class)->orderByDesc('es_principal')->orderBy('orden');
    }

    /** ¿La oferta está vigente ahora? (misma regla que v_catalogo_producto). */
    public function enOferta(): bool
    {
        return $this->precio_oferta !== null
            && ($this->oferta_inicio === null || $this->oferta_inicio->isPast())
            && ($this->oferta_fin === null || $this->oferta_fin->isFuture());
    }
}
