<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Cada cambio de estado de un pedido: de qué a qué, quién y cuándo. */
class PedidoEstadoHistorial extends Model
{
    protected $table = 'pedido_estado_historial';

    // Solo tiene created_at (lo pone la base).
    public const UPDATED_AT = null;

    protected $fillable = ['pedido_id', 'estado_anterior', 'estado_nuevo', 'motivo', 'usuario_id', 'rol'];

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(Usuario::class);
    }
}
