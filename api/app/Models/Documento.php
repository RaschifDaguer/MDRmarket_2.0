<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Collection;

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

    // ---------- Identidad: carnet (los dos lados) y selfie se revisan juntos ----------
    // En la base son documentos separados, pero en el panel son UNA solicitud:
    // una fila, las fotos lado a lado (para comparar la cara de la selfie con
    // la del carnet) y se aprueban o rechazan a la vez.

    public const CI_ANVERSO = 'ci_anverso';

    public const CI_REVERSO = 'ci_reverso';

    public const ROSTRO = 'foto_rostro';

    /** Partes de la identidad, en el orden en que se muestran. */
    public const IDENTIDAD = [self::CI_ANVERSO => 'anverso', self::CI_REVERSO => 'reverso', self::ROSTRO => 'rostro'];

    private ?Collection $solicitud = null;

    /**
     * Una fila por solicitud: cada parte de la identidad se oculta si la misma
     * persona tiene, en el mismo estado, una parte que va antes (la fila es la
     * del anverso; si no lo subió, la del reverso; si tampoco, la selfie).
     */
    public function scopeSolicitudes(Builder $query): void
    {
        $anteriores = [];
        foreach (array_keys(self::IDENTIDAD) as $codigo) {
            if ($anteriores !== []) {
                $previos = $anteriores;
                $query->whereNot(fn (Builder $q) => $q
                    ->whereHas('tipo', fn (Builder $tipo) => $tipo->where('codigo', $codigo))
                    ->whereExists(fn ($otro) => $otro->selectRaw('1')
                        ->from('documento as otro')
                        ->join('tipo_documento as tipo_otro', 'tipo_otro.id', '=', 'otro.tipo_documento_id')
                        ->whereIn('tipo_otro.codigo', $previos)
                        ->whereColumn('otro.usuario_id', 'documento.usuario_id')
                        ->whereColumn('otro.estado', 'documento.estado')));
            }
            $anteriores[] = $codigo;
        }
    }

    /** "anverso", "reverso" o "rostro" si es parte de la identidad; null si es otro documento. */
    public function lado(): ?string
    {
        return self::IDENTIDAD[$this->tipo?->codigo] ?? null;
    }

    /**
     * Este documento y las demás partes de la identidad de la misma persona en
     * el mismo estado (la más reciente de cada una), en orden: anverso, reverso, selfie.
     */
    public function documentosDeLaSolicitud(): Collection
    {
        if ($this->lado() === null) {
            return collect([$this]);
        }

        return $this->solicitud ??= static::with('tipo')
            ->where('usuario_id', $this->usuario_id)
            ->where('estado', $this->estado)
            ->where('id', '<>', $this->id)
            ->whereHas('tipo', fn (Builder $tipo) => $tipo->whereIn('codigo', array_keys(self::IDENTIDAD)))
            ->latest('id')
            ->get()
            ->prepend($this)
            ->unique(fn (Documento $d) => $d->lado())
            ->sortBy(fn (Documento $d) => array_search($d->lado(), array_values(self::IDENTIDAD), true))
            ->values()
            ->toBase();
    }

    public function nombreSolicitud(): string
    {
        return static::nombreDe($this->documentosDeLaSolicitud());
    }

    /**
     * Nombre para mostrar: "Carnet de identidad (ambos lados)", con " y foto
     * del rostro" si va la selfie; si no están los dos lados, sus nombres.
     */
    public static function nombreDe(iterable $documentos): string
    {
        $documentos = collect($documentos);
        $lados = $documentos->map(fn (Documento $d) => $d->lado());
        if ($lados->contains('anverso') && $lados->contains('reverso')) {
            return 'Carnet de identidad (ambos lados)'.($lados->contains('rostro') ? ' y foto del rostro' : '');
        }

        return $documentos->map(fn (Documento $d) => $d->tipo->nombre)->join(', ', ' y ');
    }
}
