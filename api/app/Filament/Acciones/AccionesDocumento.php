<?php

namespace App\Filament\Acciones;

use App\Models\Documento;
use App\Support\Revision;
use Filament\Actions\Action;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Support\Icons\Heroicon;

/**
 * Botones para aprobar o rechazar un documento (carnet, licencia…). El carnet
 * (los dos lados) y la selfie son una sola solicitud: se aprueban o rechazan juntos.
 */
class AccionesDocumento
{
    /** Cómo se llama cada parte de la identidad al elegir qué rechazar. */
    private const PARTES = ['anverso' => 'Carnet: frente', 'reverso' => 'Carnet: reverso', 'rostro' => 'Foto del rostro (selfie)'];

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
            ->modalHeading(fn (Documento $record) => '¿Aprobar '.mb_strtolower($record->nombreSolicitud()).'?')
            ->modalSubmitActionLabel('Sí, aprobar')
            ->action(function (Documento $record) {
                $documentos = $record->documentosDeLaSolicitud();
                foreach ($documentos as $documento) {
                    Revision::aprobarDocumento($documento, auth()->user());
                }
                Notification::make()->title('Aprobado: '.Documento::nombreDe($documentos))->success()->send();
            });
    }

    public static function rechazar(): Action
    {
        return Action::make('rechazar')
            ->label('Rechazar')
            ->icon(Heroicon::OutlinedXCircle)
            ->color('danger')
            ->visible(fn (Documento $record) => $record->estado === 'pendiente')
            ->modalHeading(fn (Documento $record) => 'Rechazar '.mb_strtolower($record->nombreSolicitud()))
            ->modalDescription('La persona verá el motivo y tendrá que subirlo de nuevo.')
            ->schema([
                // Solo si la solicitud tiene varias fotos (carnet y selfie): cuál está mal.
                CheckboxList::make('lados')
                    ->label('¿Qué tiene que volver a subir?')
                    ->options(fn (?Documento $record) => $record?->documentosDeLaSolicitud()
                        ->mapWithKeys(fn (Documento $d) => [$d->lado() => self::PARTES[$d->lado()]])
                        ->all() ?? [])
                    ->default(fn (?Documento $record) => $record?->documentosDeLaSolicitud()
                        ->map(fn (Documento $d) => $d->lado())
                        ->all() ?? [])
                    ->helperText('Lo que no marques queda aprobado.')
                    ->required()
                    ->visible(fn (?Documento $record) => $record?->documentosDeLaSolicitud()->count() > 1),
                Textarea::make('motivo')
                    ->label('Motivo')
                    ->placeholder('Ej.: la foto está borrosa, no se lee el número, la cara no coincide con el carnet…')
                    ->required()
                    ->maxLength(255),
            ])
            ->modalSubmitActionLabel('Rechazar')
            ->action(function (Documento $record, array $data) {
                $lados = $data['lados'] ?? null;
                [$rechazados, $aprobados] = $record->documentosDeLaSolicitud()
                    ->partition(fn (Documento $d) => $lados === null || in_array($d->lado(), $lados, true));

                foreach ($aprobados as $documento) {
                    Revision::aprobarDocumento($documento, auth()->user());
                }
                Revision::rechazarDocumentos($rechazados, auth()->user(), $data['motivo']);
                Notification::make()->title('Rechazado: '.Documento::nombreDe($rechazados))->warning()->send();
            });
    }
}
