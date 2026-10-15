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

    // ---------- Carnet: anverso y reverso se revisan juntos ----------
    // En la base son dos documentos, pero en el panel son UNA solicitud: una
    // fila, las dos fotos lado a lado, y se aprueban o rechazan a la vez.

    public const CI_ANVERSO = 'ci_anverso';

    public const CI_REVERSO = 'ci_reverso';

    private Documento|false|null $parejaEncontrada = null;

    /** Una fila por solicitud: el reverso del carnet va junto a su anverso (misma persona y estado). */
    public function scopeSolicitudes(Builder $query): void
    {
        $query->whereNot(fn (Builder $q) => $q
            ->whereHas('tipo', fn (Builder $tipo) => $tipo->where('codigo', self::CI_REVERSO))
            ->whereExists(fn ($anverso) => $anverso->selectRaw('1')
                ->from('documento as anverso')
                ->join('tipo_documento as tipo_anverso', 'tipo_anverso.id', '=', 'anverso.tipo_documento_id')
                ->where('tipo_anverso.codigo', self::CI_ANVERSO)
                ->whereColumn('anverso.usuario_id', 'documento.usuario_id')
                ->whereColumn('anverso.estado', 'documento.estado')));
    }

    /** "anverso" o "reverso" si es un lado del carnet; null si es otro documento. */
    public function lado(): ?string
    {
        return match ($this->tipo?->codigo) {
            self::CI_ANVERSO => 'anverso',
            self::CI_REVERSO => 'reverso',
            default => null,
        };
    }

    /** El otro lado del carnet de la misma persona y en el mismo estado (si lo subió). */
    public function pareja(): ?Documento
    {
        $otro = match ($this->lado()) {
            'anverso' => self::CI_REVERSO,
            'reverso' => self::CI_ANVERSO,
            default => null,
        };
        if ($otro === null) {
            return null;
        }

        $this->parejaEncontrada ??= static::with('tipo')
            ->where('usuario_id', $this->usuario_id)
            ->where('estado', $this->estado)
            ->whereHas('tipo', fn (Builder $tipo) => $tipo->where('codigo', $otro))
            ->latest('id')
            ->first() ?? false;

        return $this->parejaEncontrada ?: null;
    }

    /** Este documento y su pareja (el anverso primero). */
    public function documentosDeLaSolicitud(): Collection
    {
        return collect([$this, $this->pareja()])
            ->filter()
            ->sortBy(fn (Documento $d) => $d->lado() === 'reverso' ? 1 : 0)
            ->values();
    }

    public function nombreSolicitud(): string
    {
        return static::nombreDe($this->documentosDeLaSolicitud());
    }

    /** "Carnet de identidad (ambos lados)" si van los dos lados; si no, sus nombres. */
    public static function nombreDe(iterable $documentos): string
    {
        $documentos = collect($documentos);
        if ($documentos->count() === 2 && $documentos->every(fn (Documento $d) => $d->lado() !== null)) {
            return 'Carnet de identidad (ambos lados)';
        }

        return $documentos->map(fn (Documento $d) => $d->tipo->nombre)->join(', ', ' y ');
    }
}
