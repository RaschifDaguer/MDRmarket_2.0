<?php

namespace App\Filament;

/** Cómo se muestran los estados en el panel (texto y color de la etiqueta). */
class Estados
{
    /** Las fechas se guardan en UTC y en el panel se muestran en hora de Bolivia. */
    public const ZONA = 'America/La_Paz';

    public const NEGOCIO = [
        'pendiente' => 'En revisión',
        'aprobado' => 'Activo',
        'rechazado' => 'Rechazado',
        'suspendido' => 'Suspendido',
    ];

    public const REPARTIDOR = [
        'pendiente' => 'En revisión',
        'aprobado' => 'Activo',
        'rechazado' => 'Rechazado',
        'suspendido' => 'Suspendido',
    ];

    public const VEHICULO = [
        'pendiente' => 'En revisión',
        'aprobado' => 'Aprobado',
        'rechazado' => 'Rechazado',
    ];

    public const DOCUMENTO = [
        'pendiente' => 'Por revisar',
        'aprobado' => 'Aprobado',
        'rechazado' => 'Rechazado',
    ];

    public const PEDIDO = [
        'pendiente' => 'Esperando al negocio',
        'confirmado' => 'Aceptado',
        'preparando' => 'Preparando',
        'listo' => 'Listo',
        'en_camino' => 'En camino',
        'entregado' => 'Entregado',
        'cancelado' => 'Cancelado',
        'rechazado' => 'Rechazado',
    ];

    public static function color(?string $estado): string
    {
        return match ($estado) {
            'pendiente' => 'warning',
            'aprobado', 'entregado' => 'success',
            'rechazado', 'cancelado' => 'danger',
            'suspendido' => 'gray',
            default => 'info',
        };
    }
}
