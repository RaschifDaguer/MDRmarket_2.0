<?php

namespace App\Support;

use App\Models\Documento;
use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Repartidor;
use App\Models\Usuario;
use Illuminate\Support\Facades\DB;

/**
 * Decisiones del administrador sobre negocios, repartidores y documentos. Cada una deja un
 * aviso en `notificacion` para el dueño. Las usa el panel (/admin).
 */
class Revision
{
    public static function aprobarNegocio(Negocio $negocio): void
    {
        $negocio->forceFill(['estado_verificacion' => 'aprobado'])->save();
        Notificacion::avisar($negocio->usuario_id, 'negocio_aprobado',
            '¡Tu negocio está activo!', "«{$negocio->nombre}» ya aparece en el catálogo.");
    }

    public static function rechazarNegocio(Negocio $negocio, string $motivo): void
    {
        $negocio->forceFill(['estado_verificacion' => 'rechazado'])->save();
        Notificacion::avisar($negocio->usuario_id, 'negocio_rechazado',
            'Tu negocio no fue aprobado', $motivo);
    }

    public static function suspenderNegocio(Negocio $negocio, string $motivo): void
    {
        $negocio->forceFill(['estado_verificacion' => 'suspendido'])->save();
        Notificacion::avisar($negocio->usuario_id, 'negocio_suspendido',
            'Tu negocio fue suspendido', $motivo);
    }

    /** Aprueba al repartidor y sus vehículos que estaban en revisión. */
    public static function aprobarRepartidor(Repartidor $repartidor): void
    {
        DB::transaction(function () use ($repartidor) {
            $repartidor->forceFill(['estado_verificacion' => 'aprobado', 'verificado_en' => now()])->save();
            $repartidor->vehiculos()->where('estado_verificacion', 'pendiente')->update(['estado_verificacion' => 'aprobado']);
        });
        Notificacion::avisar($repartidor->usuario_id, 'repartidor_aprobado',
            '¡Ya eres repartidor!', 'Tu cuenta de repartidor fue aprobada. Ya puedes cambiar a la vista repartidor.');
    }

    /** Rechaza al repartidor y sus vehículos que estaban en revisión. */
    public static function rechazarRepartidor(Repartidor $repartidor, string $motivo): void
    {
        DB::transaction(function () use ($repartidor) {
            $repartidor->forceFill(['estado_verificacion' => 'rechazado'])->save();
            $repartidor->vehiculos()->where('estado_verificacion', 'pendiente')->update(['estado_verificacion' => 'rechazado']);
        });
        Notificacion::avisar($repartidor->usuario_id, 'repartidor_rechazado',
            'Tu solicitud de repartidor no fue aprobada', $motivo);
    }

    public static function suspenderRepartidor(Repartidor $repartidor, string $motivo): void
    {
        $repartidor->forceFill(['estado_verificacion' => 'suspendido', 'disponible' => false])->save();
        Notificacion::avisar($repartidor->usuario_id, 'repartidor_suspendido',
            'Tu cuenta de repartidor fue suspendida', $motivo);
    }

    public static function aprobarDocumento(Documento $documento, Usuario $admin): void
    {
        $documento->forceFill([
            'estado' => 'aprobado',
            'observacion' => null,
            'revisado_por' => $admin->id,
            'revisado_en' => now(),
        ])->save();
    }

    /**
     * Rechaza uno o varios documentos de la misma persona (ej. los dos lados
     * del carnet) y le deja un solo aviso con lo que debe volver a subir.
     *
     * @param  iterable<Documento>  $documentos
     */
    public static function rechazarDocumentos(iterable $documentos, Usuario $admin, string $motivo): void
    {
        $documentos = collect($documentos);
        foreach ($documentos as $documento) {
            $documento->forceFill([
                'estado' => 'rechazado',
                'observacion' => $motivo,
                'revisado_por' => $admin->id,
                'revisado_en' => now(),
            ])->save();
        }
        Notificacion::avisar($documentos->first()->usuario_id, 'documento_rechazado',
            'Vuelve a subir: '.Documento::nombreDe($documentos), $motivo);
    }
}
