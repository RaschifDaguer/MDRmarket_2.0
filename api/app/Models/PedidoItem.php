<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Ítem de un pedido. Al insertarlo, trg_pedido_item_bi descuenta el stock
 * (o falla con "Stock insuficiente") y copia el costo del producto.
 * `subtotal` lo calcula la base.
 */
class PedidoItem extends Model
{
    protected $table = 'pedido_item';

    protected $fillable = ['pedido_id', 'producto_id', 'producto_nombre', 'precio_unitario', 'cantidad', 'notas'];

    protected function casts(): array
    {
        return [
            'precio_unitario' => 'decimal:2',
            'subtotal' => 'decimal:2',
            'cantidad' => 'integer',
        ];
    }

    public function producto(): BelongsTo
    {
        return $this->belongsTo(Producto::class)->withTrashed();
    }
}
