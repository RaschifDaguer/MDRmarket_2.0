<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Documento subido por un usuario (foto del carnet, licencia, RUAT, NIT…).
 * `archivo_url` guarda la ruta interna en el disco privado, no una URL pública.
 * Lo revisa un administrador desde el panel (estado, observacion, revisado_por).
 */
class Documento extends Model
{
    protected $table = 'documento';

    protected $fillable = [
        'usuario_id',
        'tipo_documento_id',
        'vehiculo_id',
        'negocio_id',
        'archivo_url',
        'numero',
    ];

    protected function casts(): array
    {
        return ['revisado_en' => 'datetime'];
    }

    public function tipo(): BelongsTo
    {
        return $this->belongsTo(TipoDocumento::class, 'tipo_documento_id');
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(Usuario::class);
    }

    public function negocio(): BelongsTo
    {
        return $this->belongsTo(Negocio::class)->withTrashed();
    }

    public function revisor(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'revisado_por');
    }

    /** ¿Es una foto (se muestra) o un PDF (se descarga)? */
    public function esImagen(): bool
    {
        return in_array(strtolower(pathinfo($this->archivo_url, PATHINFO_EXTENSION)), ['jpg', 'jpeg', 'png', 'webp'], true);
    }
}
