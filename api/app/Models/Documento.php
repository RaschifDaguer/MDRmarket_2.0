<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Documento subido por un usuario (foto del carnet, licencia, RUAT, NIT…).
 * `archivo_url` guarda la ruta interna en el disco privado, no una URL pública.
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

    public function tipo(): BelongsTo
    {
        return $this->belongsTo(TipoDocumento::class, 'tipo_documento_id');
    }
}
