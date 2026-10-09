<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Horario de atención: una fila por tramo (dia_semana 1 = lunes … 7 = domingo). */
class NegocioHorario extends Model
{
    protected $table = 'negocio_horario';

    public $timestamps = false;

    protected $fillable = ['negocio_id', 'dia_semana', 'hora_apertura', 'hora_cierre'];

    protected function casts(): array
    {
        return ['dia_semana' => 'integer'];
    }
}
