<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Liviano (moto, bici), mediano (auto, camioneta) o grande (camión). */
class CategoriaVehiculo extends Model
{
    protected $table = 'categoria_vehiculo';

    public $timestamps = false;
}
