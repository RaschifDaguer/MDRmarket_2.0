<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Reseña de un producto, negocio o repartidor. Una por usuario y objetivo:
 * si cambia de opinión, se edita la misma. La base controla que solo
 * reseñe quien recibió un pedido y que nadie se reseñe a sí mismo.
 */
class Resena extends Model
{
    protected $table = 'resena';

    protected $fillable = [
        'autor_id',
        'tipo',
        'producto_id',
        'negocio_id',
        'repartidor_id',
        'estrellas',
        'comentario',
        'respuesta',
        'respondido_en',
        'visible',
    ];

    protected function casts(): array
    {
        return [
            'estrellas' => 'integer',
            'visible' => 'boolean',
            'respondido_en' => 'datetime',
        ];
    }

    public function autor(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'autor_id');
    }

    public function producto(): BelongsTo
    {
        return $this->belongsTo(Producto::class)->withTrashed();
    }

    public function negocio(): BelongsTo
    {
        return $this->belongsTo(Negocio::class)->withTrashed();
    }
}
