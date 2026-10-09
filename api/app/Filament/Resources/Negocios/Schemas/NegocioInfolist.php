<?php

namespace App\Filament\Resources\Negocios\Schemas;

use App\Filament\Estados;
use App\Models\Documento;
use App\Models\Negocio;
use App\Support\Archivos;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

/** Todo lo que el administrador necesita para decidir si aprueba el negocio. */
class NegocioInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema->components([
            Grid::make(['default' => 1, 'lg' => 3])
                ->columnSpanFull()
                ->schema([
                    Section::make('Negocio')
                        ->columnSpan(['lg' => 2])
                        ->columns(2)
                        ->schema([
                            ImageEntry::make('logo_url')
                                ->label('Foto del negocio')
                                ->state(fn (Negocio $record) => Archivos::url($record->logo_url))
                                ->imageHeight(220)
                                ->columnSpanFull(),
                            TextEntry::make('nombre')->weight('bold'),
                            TextEntry::make('estado_verificacion')
                                ->label('Estado')
                                ->badge()
                                ->formatStateUsing(fn (string $state) => Estados::NEGOCIO[$state] ?? $state)
                                ->color(fn (string $state) => Estados::color($state)),
                            TextEntry::make('categoria.nombre')->label('Rubro'),
                            TextEntry::make('telefono')->label('Teléfono')->placeholder('—'),
                            TextEntry::make('descripcion')->label('Descripción')->placeholder('—')->columnSpanFull(),
                            TextEntry::make('direccion')->label('Dirección')->placeholder('—'),
                            TextEntry::make('referencia')->placeholder('—'),
                            TextEntry::make('ubicacion')
                                ->label('Ubicación')
                                ->state(fn (Negocio $record) => $record->latitud ? 'Ver en Google Maps' : null)
                                ->url(fn (Negocio $record) => $record->latitud
                                    ? "https://www.google.com/maps?q={$record->latitud},{$record->longitud}"
                                    : null)
                                ->openUrlInNewTab()
                                ->color('primary')
                                ->placeholder('Sin ubicación'),
                            TextEntry::make('created_at')
                                ->label('Registrado')
                                ->dateTime('d/m/Y H:i')
                                ->timezone(Estados::ZONA),
                            TextEntry::make('nit')->label('NIT')->placeholder('No tiene'),
                            TextEntry::make('razon_social')->label('Nombre para facturas')->placeholder('—'),
                        ]),
                    Section::make('Dueño')
                        ->columnSpan(1)
                        ->schema([
                            TextEntry::make('usuario.nombre_completo')->label('Nombre'),
                            TextEntry::make('usuario.email')->label('Correo')->copyable(),
                            TextEntry::make('usuario.telefono')->label('Teléfono')->placeholder('—'),
                            TextEntry::make('usuario.ci_numero')
                                ->label('Carnet')
                                ->formatStateUsing(fn (Negocio $record) => trim(
                                    $record->usuario->ci_numero.' '.$record->usuario->ci_complemento.' '.$record->usuario->ci_expedido))
                                ->placeholder('—'),
                        ]),
                ]),
            Section::make('Documentos del dueño')
                ->description('Revisa que el carnet coincida con el nombre del dueño. Se aprueban en Aprobaciones → Documentos.')
                ->columnSpanFull()
                ->schema([
                    RepeatableEntry::make('usuario.documentos')
                        ->hiddenLabel()
                        ->grid(['default' => 1, 'md' => 2])
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
