<?php

namespace App\Filament\Resources\Repartidores\Schemas;

use App\Filament\Estados;
use App\Models\Documento;
use App\Models\Repartidor;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

/** Todo lo que el administrador necesita para decidir si aprueba al repartidor. */
class RepartidorInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema->components([
            Grid::make(['default' => 1, 'lg' => 3])
                ->columnSpanFull()
                ->schema([
                    Section::make('Vehículo')
                        ->columnSpan(['lg' => 2])
                        ->schema([
                            RepeatableEntry::make('vehiculos')
                                ->hiddenLabel()
                                ->placeholder('Todavía no registró un vehículo.')
                                ->columns(['default' => 2, 'md' => 4])
                                ->schema([
                                    TextEntry::make('tipo.nombre')->label('Tipo')->weight('bold'),
                                    TextEntry::make('estado_verificacion')
                                        ->label('Estado')
                                        ->badge()
                                        ->formatStateUsing(fn (string $state) => Estados::VEHICULO[$state] ?? $state)
                                        ->color(fn (string $state) => Estados::color($state)),
                                    TextEntry::make('placa')->placeholder('No tiene')->copyable(),
                                    TextEntry::make('ruat')->label('RUAT')->placeholder('No tiene')->copyable(),
                                    TextEntry::make('marca')->placeholder('—'),
                                    TextEntry::make('modelo')->placeholder('—'),
                                    TextEntry::make('color')->placeholder('—'),
                                    TextEntry::make('anio')->label('Año')->placeholder('—'),
                                ]),
                        ]),
                    Section::make('Repartidor')
                        ->columnSpan(1)
                        ->schema([
                            TextEntry::make('usuario.nombre_completo')->label('Nombre')->weight('bold'),
                            TextEntry::make('estado_verificacion')
                                ->label('Estado')
                                ->badge()
                                ->formatStateUsing(fn (string $state) => Estados::REPARTIDOR[$state] ?? $state)
                                ->color(fn (string $state) => Estados::color($state)),
                            TextEntry::make('usuario.email')->label('Correo')->copyable(),
                            TextEntry::make('usuario.telefono')->label('Teléfono')->placeholder('—'),
                            TextEntry::make('usuario.ci_numero')
                                ->label('Carnet')
                                ->formatStateUsing(fn (Repartidor $record) => trim(
                                    $record->usuario->ci_numero.' '.$record->usuario->ci_complemento.' '.$record->usuario->ci_expedido))
                                ->placeholder('—'),
                            TextEntry::make('created_at')
                                ->label('Registrado')
                                ->dateTime('d/m/Y H:i')
                                ->timezone(Estados::ZONA),
                            TextEntry::make('verificado_en')
                                ->label('Aprobado el')
                                ->dateTime('d/m/Y H:i')
                                ->timezone(Estados::ZONA)
                                ->placeholder('—'),
                        ]),
                ]),
            Section::make('Documentos')
                ->description('Revisa que el carnet coincida con la selfie, y la placa y el RUAT con los datos del vehículo. Se aprueban en Aprobaciones → Documentos.')
                ->columnSpanFull()
                ->schema([
                    RepeatableEntry::make('usuario.documentos')
                        ->hiddenLabel()
                        ->grid(['default' => 1, 'md' => 2, 'xl' => 3])
                        ->placeholder('Todavía no subió documentos.')
                        ->schema([
                            TextEntry::make('tipo.nombre')->hiddenLabel()->weight('bold'),
                            TextEntry::make('estado')
                                ->hiddenLabel()
                                ->badge()
                                ->formatStateUsing(fn (string $state) => Estados::DOCUMENTO[$state] ?? $state)
                                ->color(fn (string $state) => Estados::color($state)),
                            ImageEntry::make('archivo_url')
                                ->hiddenLabel()
                                ->state(fn (Documento $record) => $record->esImagen()
                                    ? route('panel.documento.archivo', $record) : null)
                                ->url(fn (Documento $record) => route('panel.documento.archivo', $record))
                                ->openUrlInNewTab()
                                ->imageHeight(180)
                                ->placeholder('Archivo PDF (clic para abrir)'),
                        ]),
                ]),
        ]);
    }
}
