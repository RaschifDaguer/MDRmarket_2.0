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
    public const ESTADOS = ['pendiente' => 'Pendiente', 'en_revision' => 'En revisión', 'resuelto' => 'Resuelto', 'descartado' => 'Descartado'];

    public const TIPOS = ['producto' => 'Producto', 'negocio' => 'Tienda', 'repartidor' => 'Repartidor', 'usuario' => 'Cliente', 'resena' => 'Reseña'];

    protected $table = 'reporte';

    protected $fillable = [
        'reportante_id', 'tipo', 'producto_id', 'negocio_id', 'repartidor_id', 'usuario_id', 'resena_id',
        'motivo_id', 'pedido_id', 'descripcion',
    ];

    protected function casts(): array
    {
        return ['revisado_en' => 'datetime'];
    }

    public function motivo(): BelongsTo
    {
        return $this->belongsTo(MotivoReporte::class, 'motivo_id');
    }

    public function reportante(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'reportante_id');
    }

    public function negocio(): BelongsTo
    {
        return $this->belongsTo(Negocio::class);
    }

    /** El usuario del repartidor reportado (repartidor.usuario_id = usuario.id). */
    public function repartidorUsuario(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'repartidor_id');
    }

    public function producto(): BelongsTo
    {
        return $this->belongsTo(Producto::class);
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(Usuario::class);
    }

    public function revisor(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'revisado_por');
    }

    /** ¿Sigue abierto (pendiente o en revisión)? */
    public function estaAbierto(): bool
    {
        return in_array($this->estado, ['pendiente', 'en_revision'], true);
    }

    /** A quién o qué se reportó, para mostrar ("Tienda: FarmaSuper"). */
    public function objetivoTexto(): string
    {
        $nombre = match ($this->tipo) {
            'negocio' => $this->negocio?->nombre,
            'repartidor' => $this->repartidorUsuario?->nombre_completo,
            'producto' => $this->producto?->nombre,
            'usuario' => $this->usuario?->nombre_completo,
            default => '#'.$this->resena_id,
        };

        return (self::TIPOS[$this->tipo] ?? $this->tipo).': '.($nombre ?? '—');
    }
}
