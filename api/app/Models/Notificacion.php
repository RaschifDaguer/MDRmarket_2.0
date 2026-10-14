<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Aviso para un usuario (negocio aprobado, pedido nuevo…). */
class Notificacion extends Model
{
    protected $table = 'notificacion';

    // Solo tiene created_at.
    public const UPDATED_AT = null;

    protected $fillable = ['usuario_id', 'pedido_id', 'tipo', 'titulo', 'cuerpo', 'datos', 'leida_en'];

    protected function casts(): array
    {
        return [
            'datos' => 'array',
            'leida_en' => 'datetime',
        ];
    }

    /** Atajo para avisar algo a un usuario. */
    public static function avisar(int $usuarioId, string $tipo, string $titulo, ?string $cuerpo = null, ?int $pedidoId = null): void
    {
        static::create([
            'usuario_id' => $usuarioId,
            'pedido_id' => $pedidoId,
            'tipo' => $tipo,
            'titulo' => $titulo,
            'cuerpo' => $cuerpo,
        ]);
    }
}
