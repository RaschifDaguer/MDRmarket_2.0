<?php

namespace App\Filament\Acciones;

use App\Models\Repartidor;
use App\Support\Revision;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;

/** Botones para aprobar, rechazar o suspender a un repartidor (lista y detalle). */
class AccionesRepartidor
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
            ->visible(fn (Repartidor $record) => $record->estado_verificacion !== 'aprobado')
            // Sin vehículo no puede llevar pedidos.
            ->disabled(fn (Repartidor $record) => ! $record->vehiculos()->exists())
            ->tooltip(fn (Repartidor $record) => $record->vehiculos()->exists() ? null : 'Todavía no registró un vehículo.')
            ->requiresConfirmation()
            ->modalHeading(fn (Repartidor $record) => "¿Aprobar a {$record->usuario->nombre_completo} como repartidor?")
            ->modalDescription('También se aprueba su vehículo. Sus documentos se aprueban en Aprobaciones → Documentos.')
            ->modalSubmitActionLabel('Sí, aprobar')
            ->action(function (Repartidor $record) {
                Revision::aprobarRepartidor($record);
                Notification::make()->title('Repartidor aprobado')->success()->send();
            });
    }

    public static function rechazar(): Action
    {
        return Action::make('rechazar')
            ->label('Rechazar')
            ->icon(Heroicon::OutlinedXCircle)
            ->color('danger')
            ->visible(fn (Repartidor $record) => $record->estado_verificacion === 'pendiente')
            ->modalHeading(fn (Repartidor $record) => "Rechazar a {$record->usuario->nombre_completo}")
            ->schema([
                Textarea::make('motivo')
                    ->label('Motivo (lo verá el repartidor)')
                    ->placeholder('Ej.: la placa no coincide con la foto, el RUAT está a nombre de otra persona…')
                    ->required()
                    ->maxLength(255),
            ])
            ->modalSubmitActionLabel('Rechazar')
            ->action(function (Repartidor $record, array $data) {
                Revision::rechazarRepartidor($record, $data['motivo']);
                Notification::make()->title('Repartidor rechazado')->warning()->send();
            });
    }

    public static function suspender(): Action
    {
        return Action::make('suspender')
            ->label('Suspender')
            ->icon(Heroicon::OutlinedNoSymbol)
            ->color('gray')
            ->visible(fn (Repartidor $record) => $record->estado_verificacion === 'aprobado')
            ->modalHeading(fn (Repartidor $record) => "Suspender a {$record->usuario->nombre_completo}")
            ->modalDescription('No podrá llevar pedidos hasta que lo vuelvas a aprobar.')
            ->schema([
                Textarea::make('motivo')->label('Motivo')->required()->maxLength(255),
            ])
            ->modalSubmitActionLabel('Suspender')
            ->action(function (Repartidor $record, array $data) {
                Revision::suspenderRepartidor($record, $data['motivo']);
                Notification::make()->title('Repartidor suspendido')->warning()->send();
            });
    }
}
