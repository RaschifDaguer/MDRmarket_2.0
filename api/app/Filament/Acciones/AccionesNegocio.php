<?php

namespace App\Filament\Acciones;

use App\Models\Negocio;
use App\Support\Revision;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;

/** Botones para aprobar, rechazar o suspender un negocio (lista y detalle). */
class AccionesNegocio
{
    /** @return array<Action> */
    public static function todas(): array
    {
        return [static::aprobar(), static::rechazar(), static::suspender()];
    }

    public static function aprobar(): Action
    {
        return Action::make('aprobar')
            ->label('Aprobar')
            ->icon(Heroicon::OutlinedCheckCircle)
            ->color('success')
            ->visible(fn (Negocio $record) => $record->estado_verificacion !== 'aprobado')
            ->requiresConfirmation()
            ->modalHeading(fn (Negocio $record) => "¿Aprobar «{$record->nombre}»?")
            ->modalDescription('El negocio aparecerá en el catálogo y podrá recibir pedidos.')
            ->modalSubmitActionLabel('Sí, aprobar')
            ->action(function (Negocio $record) {
                Revision::aprobarNegocio($record);
                Notification::make()->title('Negocio aprobado')->success()->send();
            });
    }

    public static function rechazar(): Action
    {
        return Action::make('rechazar')
            ->label('Rechazar')
            ->icon(Heroicon::OutlinedXCircle)
            ->color('danger')
            ->visible(fn (Negocio $record) => $record->estado_verificacion === 'pendiente')
            ->modalHeading(fn (Negocio $record) => "Rechazar «{$record->nombre}»")
            ->schema([
                Textarea::make('motivo')
                    ->label('Motivo (lo verá el comerciante)')
                    ->placeholder('Ej.: la foto no muestra el negocio, la dirección no coincide…')
                    ->required()
                    ->maxLength(255),
            ])
            ->modalSubmitActionLabel('Rechazar')
            ->action(function (Negocio $record, array $data) {
                Revision::rechazarNegocio($record, $data['motivo']);
                Notification::make()->title('Negocio rechazado')->warning()->send();
            });
    }

    public static function suspender(): Action
    {
        return Action::make('suspender')
            ->label('Suspender')
            ->icon(Heroicon::OutlinedNoSymbol)
            ->color('gray')
            ->visible(fn (Negocio $record) => $record->estado_verificacion === 'aprobado')
            ->modalHeading(fn (Negocio $record) => "Suspender «{$record->nombre}»")
            ->modalDescription('Sale del catálogo hasta que lo vuelvas a aprobar.')
            ->schema([
                Textarea::make('motivo')->label('Motivo')->required()->maxLength(255),
            ])
            ->modalSubmitActionLabel('Suspender')
            ->action(function (Negocio $record, array $data) {
                Revision::suspenderNegocio($record, $data['motivo']);
                Notification::make()->title('Negocio suspendido')->warning()->send();
            });
    }
}
