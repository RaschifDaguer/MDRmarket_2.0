<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Categoría de dos niveles: principal (sin padre) y subcategoría. */
class Categoria extends Model
{
    protected $table = 'categoria';

    protected $fillable = ['categoria_padre_id', 'nombre', 'icono', 'descripcion', 'orden', 'activo'];

    protected function casts(): array
    {
        return ['activo' => 'boolean'];
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
