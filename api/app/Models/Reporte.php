<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Reporte de un problema (un negocio, repartidor, producto…). La base revisa
 * que el motivo corresponda, que nadie se reporte a sí mismo y que a una
 * persona solo la reporte quien compartió un pedido con ella (trg_reporte_bi).
 */
class Reporte extends Model
{
    protected $table = 'reporte';

    protected $fillable = [
        'reportante_id', 'tipo', 'producto_id', 'negocio_id', 'repartidor_id', 'usuario_id', 'resena_id',
        'motivo_id', 'pedido_id', 'descripcion',
    ];

    public function motivo(): BelongsTo
    {
        return $this->belongsTo(MotivoReporte::class, 'motivo_id');
    }
}
