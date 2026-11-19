<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Categoría de dos niveles: principal (sin padre) y subcategoría. */
class Categoria extends Model
{
    protected $table = 'categoria';

    /** Categoría principal "Tabaco" (cigarrillos y parecidos, solo mayores de 18). */
    public const TABACO = 15;

    protected $fillable = ['categoria_padre_id', 'nombre', 'icono', 'descripcion', 'orden', 'activo', 'solo_mayores', 'permiso'];

    protected function casts(): array
    {
        return ['activo' => 'boolean', 'solo_mayores' => 'boolean'];
    }

    /**
     * Ids de las categorías solo para mayores de 18 (bebidas alcohólicas).
     * Se consulta una vez por solicitud, aunque el catálogo tenga 20 productos.
     *
     * @return list<int>
     */
    public static function idsSoloMayores(): array
    {
        return once(fn () => static::where('solo_mayores', true)->pluck('id')->map(fn ($id) => (int) $id)->all());
    }

    public function subcategorias(): HasMany
    {
        return $this->hasMany(Categoria::class, 'categoria_padre_id')
            ->where('activo', true)
            ->orderBy('orden');
    }

    public function scopePrincipales(Builder $query): Builder
    {
        return $query->whereNull('categoria_padre_id')->where('activo', true)->orderBy('orden');
    }
}
