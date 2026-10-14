<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Libro de compras, ventas y gastos de un negocio.
 * - venta y comision: las crea la base al entregar un pedido.
 * - compra: la carga el comerciante; la base suma el stock y guarda el costo.
 * - gasto: alquiler, luz, bolsas… (costo_unitario = monto).
 * ingreso, egreso, costo_vendido y ganancia los calcula la base.
 */
class RegistroComercio extends Model
{
    protected $table = 'registro_comercio';

    protected $fillable = [
        'negocio_id',
        'tipo',
        'producto_id',
        'cantidad',
        'precio_unitario',
        'costo_unitario',
        'descripcion',
        'proveedor',
        'fecha',
        'registrado_por',
    ];

    protected function casts(): array
    {
        return [
            'cantidad' => 'integer',
            'precio_unitario' => 'decimal:2',
            'costo_unitario' => 'decimal:2',
            'ingreso' => 'decimal:2',
            'egreso' => 'decimal:2',
            'ganancia' => 'decimal:2',
            'fecha' => 'datetime',
        ];
    }

    public function producto(): BelongsTo
    {
        return $this->belongsTo(Producto::class)->withTrashed();
    }
}
