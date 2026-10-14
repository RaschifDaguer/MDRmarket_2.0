<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Dirección guardada por un usuario para recibir pedidos. */
class Direccion extends Model
{
    protected $table = 'direccion';

    protected $fillable = ['usuario_id', 'etiqueta', 'direccion', 'referencia', 'latitud', 'longitud', 'predeterminada'];

    protected function casts(): array
    {
        return [
            'latitud' => 'float',
            'longitud' => 'float',
            'predeterminada' => 'boolean',
        ];
    }
}
