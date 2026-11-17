<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Foto de un producto. `url` guarda lo que devuelve Archivos::guardarPublico(). */
class ProductoImagen extends Model
{
    /** Fotos que puede tener un producto (portada incluida). */
    public const MAXIMO = 4;

    protected $table = 'producto_imagen';

    protected $fillable = ['producto_id', 'url', 'orden', 'es_principal'];

    protected function casts(): array
    {
        return ['es_principal' => 'boolean'];
    }
}
