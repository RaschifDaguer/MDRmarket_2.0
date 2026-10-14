<?php

namespace App\Support;

use App\Models\Documento;
use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Usuario;

/**
 * Decisiones del administrador sobre negocios y documentos. Cada una deja un
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

    public static function aprobarDocumento(Documento $documento, Usuario $admin): void
    {
        $documento->forceFill([
            'estado' => 'aprobado',
            'observacion' => null,
            'revisado_por' => $admin->id,
            'revisado_en' => now(),
        ])->save();
    }

    public static function rechazarDocumento(Documento $documento, Usuario $admin, string $motivo): void
    {
        $documento->forceFill([
            'estado' => 'rechazado',
            'observacion' => $motivo,
            'revisado_por' => $admin->id,
            'revisado_en' => now(),
        ])->save();
        Notificacion::avisar($documento->usuario_id, 'documento_rechazado',
            'Vuelve a subir: '.$documento->tipo->nombre, $motivo);
    }
}
