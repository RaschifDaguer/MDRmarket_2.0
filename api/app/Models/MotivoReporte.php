<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Motivo para reportar algo ("Pedido incompleto…"). `aplica_a` = qué se puede reportar con él. */
class MotivoReporte extends Model
{
    protected $table = 'motivo_reporte';

    public $timestamps = false;

    protected function casts(): array
    {
        return ['activo' => 'boolean'];
    }

    /** ¿Sirve para reportar este tipo (negocio, repartidor…)? */
    public function aplicaA(string $tipo): bool
    {
        return in_array($tipo, explode(',', (string) $this->aplica_a), true);
    }
}
