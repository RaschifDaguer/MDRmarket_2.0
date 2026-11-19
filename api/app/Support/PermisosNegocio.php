<?php

namespace App\Support;

use App\Models\Categoria;
use App\Models\Documento;
use App\Models\Negocio;
use App\Models\TipoDocumento;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

/**
 * Permisos especiales de un negocio: vender bebidas alcohólicas (licorería)
 * o medicamentos (farmacia). Cada permiso pide documentos extra, definidos en
 * la base (tipo_documento.condicion_negocio + requisito_rol):
 *   alcohol  → Autorización de expendio + Licencia de funcionamiento
 *   farmacia → Resolución del SEDES + Licencia de funcionamiento
 */
class PermisosNegocio
{
    public const NOMBRES = [
        'alcohol' => 'vender bebidas alcohólicas',
        'farmacia' => 'vender medicamentos',
    ];

    /** Permisos que tiene marcados el negocio. @return list<string> */
    public static function delNegocio(Negocio $negocio): array
    {
        return array_values(array_filter([
            $negocio->vende_alcohol ? 'alcohol' : null,
            $negocio->es_farmacia ? 'farmacia' : null,
        ]));
    }

    /** Documentos obligatorios para ese permiso. @return Collection<int, TipoDocumento> */
    public static function documentos(string $permiso): Collection
    {
        return TipoDocumento::query()
            ->where('activo', true)
            ->where('ambito', 'negocio')
            ->whereRaw('FIND_IN_SET(?, condicion_negocio) > 0', [$permiso])
            ->whereIn('id', fn ($q) => $q->select('tipo_documento_id')->from('requisito_rol')
                ->where('rol', 'comerciante')->where('obligatorio', 1))
            ->orderBy('id')
            ->get();
    }

    /**
     * Documentos de ese permiso que todavía no están aprobados para el negocio.
     *
     * @return Collection<int, TipoDocumento>
     */
    public static function sinAprobar(Negocio $negocio, string $permiso): Collection
    {
        $aprobados = Documento::where('negocio_id', $negocio->id)
            ->where('estado', 'aprobado')
            ->pluck('tipo_documento_id')
            ->map(fn ($id) => (int) $id)
            ->all();

        return static::documentos($permiso)
            ->reject(fn (TipoDocumento $t) => in_array((int) $t->id, $aprobados, true))
            ->values();
    }

    /**
     * Documentos que le falta aprobar al negocio según sus permisos (para el
     * panel). La licencia de funcionamiento cuenta una sola vez.
     *
     * @return list<string>
     */
    public static function pendientes(Negocio $negocio): array
    {
        $pendientes = [];
        foreach (static::delNegocio($negocio) as $permiso) {
            foreach (static::sinAprobar($negocio, $permiso) as $tipo) {
                $pendientes[$tipo->codigo] = $tipo->nombre;
            }
        }

        return array_values($pendientes);
    }

    /**
     * Publicar un producto en una categoría que pide permiso (bebidas
     * alcohólicas, medicamentos):
     *   - el negocio tiene que tener marcado ese permiso;
     *   - si ya está aprobado (se ve en el catálogo), sus documentos de ese
     *     permiso tienen que estar aprobados. Si está en revisión, el
     *     administrador los revisa antes de aprobar el negocio.
     * Si no, 422 en "categoria_id".
     */
    public static function exigirParaCategoria(Negocio $negocio, int $categoriaId): void
    {
        $permiso = Categoria::whereKey($categoriaId)->value('permiso');
        if ($permiso === null) {
            return;
        }

        if (! in_array($permiso, static::delNegocio($negocio), true)) {
            throw ValidationException::withMessages(['categoria_id' => $permiso === 'alcohol'
                ? 'Para vender bebidas alcohólicas, marca «Vendo bebidas alcohólicas» en el perfil de tu negocio y sube sus permisos.'
                : 'Solo las farmacias pueden vender medicamentos. Marca «Es una farmacia» en el perfil de tu negocio y sube sus permisos.']);
        }

        if ($negocio->estaAprobado() && ($faltan = static::sinAprobar($negocio, $permiso))->isNotEmpty()) {
            throw ValidationException::withMessages(['categoria_id' => 'Para '.self::NOMBRES[$permiso]
                .' tienen que estar aprobados: '.$faltan->pluck('nombre')->implode(', ')
                .'. Súbelos en Más → Documentos; te avisamos cuando los revisemos.']);
        }
    }
}
