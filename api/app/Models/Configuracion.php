<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Parámetros editables sin tocar código (tarifa de servicio, comisión…). */
class Configuracion extends Model
{
    protected $table = 'configuracion';

    protected $primaryKey = 'clave';

    protected $keyType = 'string';

    public $incrementing = false;

    // Solo tiene updated_at.
    public const CREATED_AT = null;

    protected $fillable = ['valor'];

    /** Valor de un parámetro, o $defecto si no existe. */
    public static function valor(string $clave, mixed $defecto = null): mixed
    {
        return static::query()->whereKey($clave)->value('valor') ?? $defecto;
    }
}
