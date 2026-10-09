<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Catálogo de documentos que se pueden pedir (carnet, licencia, RUAT, NIT…). */
class TipoDocumento extends Model
{
    protected $table = 'tipo_documento';

    public $timestamps = false;
}
