<?php

namespace App\Filament\Acciones;

use App\Models\Documento;
use App\Support\Revision;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;

/** Botones para aprobar o rechazar un documento (carnet, licencia…). */
class AccionesDocumento
{
    /** @return array<Action> */
    public static function todas(): array
    {
        return [static::aprobar(), static::rechazar()];
    }

    public static function aprobar(): Action
    {
        return Action::make('aprobar')
            ->label('Aprobar')
            ->icon(Heroicon::OutlinedCheckCircle)
            ->color('success')
            ->visible(fn (Documento $record) => $record->estado !== 'aprobado')
            ->requiresConfirmation()
            ->modalHeading('¿Aprobar este documento?')
            ->modalSubmitActionLabel('Sí, aprobar')
            ->action(function (Documento $record) {
                Revision::aprobarDocumento($record, auth()->user());
                Notification::make()->title('Documento aprobado')->success()->send();
            });
    }

    public static function rechazar(): Action
    {
        return Action::make('rechazar')
            ->label('Rechazar')
            ->icon(Heroicon::OutlinedXCircle)
            ->color('danger')
            ->visible(fn (Documento $record) => $record->estado === 'pendiente')
            ->modalHeading('Rechazar documento')
            ->modalDescription('La persona verá el motivo y tendrá que subirlo de nuevo.')
            ->schema([
                Textarea::make('motivo')
                    ->label('Motivo')
                    ->placeholder('Ej.: la foto está borrosa, no se lee el número…')
                    ->required()
                    ->maxLength(255),
            ])
            ->modalSubmitActionLabel('Rechazar')
            ->action(function (Documento $record, array $data) {
                Revision::rechazarDocumento($record, auth()->user(), $data['motivo']);
                Notification::make()->title('Documento rechazado')->warning()->send();
            });
    }
}
