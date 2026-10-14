<?php

namespace App\Filament\Resources\Documentos;

use App\Filament\Acciones\AccionesDocumento;
use App\Filament\Estados;
use App\Filament\Resources\Documentos\Pages\ListDocumentos;
use App\Filament\Resources\Documentos\Pages\ViewDocumento;
use App\Filament\Resources\Negocios\NegocioResource;
use App\Models\Documento;
use BackedEnum;
use Filament\Actions\ActionGroup;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use UnitEnum;

/** Fotos de carnet, licencia, RUAT… que suben comerciantes y repartidores. */
class DocumentoResource extends Resource
{
    protected static ?string $model = Documento::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedIdentification;

    protected static string|UnitEnum|null $navigationGroup = 'Aprobaciones';

    protected static ?int $navigationSort = 2;

    protected static ?string $modelLabel = 'documento';

    protected static ?string $pluralModelLabel = 'documentos';

    public static function getNavigationBadge(): ?string
    {
        $pendientes = Documento::where('estado', 'pendiente')->count();

        return $pendientes > 0 ? (string) $pendientes : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['usuario', 'tipo', 'negocio']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('usuario.nombre')
                    ->label('Persona')
                    ->formatStateUsing(fn (Documento $record) => $record->usuario?->nombre_completo)
                    ->description(fn (Documento $record) => $record->usuario?->email)
                    ->searchable(['nombre', 'apellido', 'email']),
                TextColumn::make('tipo.nombre')->label('Documento'),
                TextColumn::make('negocio.nombre')->label('Negocio')->placeholder('—'),
                TextColumn::make('estado')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => Estados::DOCUMENTO[$state] ?? $state)
                    ->color(fn (string $state) => Estados::color($state)),
                TextColumn::make('created_at')
                    ->label('Subido')
                    ->since()
                    ->timezone(Estados::ZONA)
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('tipo_documento_id')->label('Tipo')->relationship('tipo', 'nombre'),
            ])
            ->recordActions([
                ViewAction::make()->label('Ver'),
                ActionGroup::make(AccionesDocumento::todas()),
            ])
            ->emptyStateHeading('No hay documentos en esta lista');
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Foto')
                ->columnSpan(['lg' => 2])
                ->schema([
                    ImageEntry::make('archivo_url')
                        ->hiddenLabel()
                        ->state(fn (Documento $record) => $record->esImagen()
                            ? route('panel.documento.archivo', $record) : null)
                        ->url(fn (Documento $record) => route('panel.documento.archivo', $record))
                        ->openUrlInNewTab()
                        ->imageHeight(420)
                        ->placeholder('Es un PDF: haz clic para abrirlo.'),
                ]),
            Section::make('Datos')
                ->columnSpan(1)
                ->schema([
                    TextEntry::make('tipo.nombre')->label('Documento')->weight('bold'),
                    TextEntry::make('estado')
                        ->badge()
                        ->formatStateUsing(fn (string $state) => Estados::DOCUMENTO[$state] ?? $state)
                        ->color(fn (string $state) => Estados::color($state)),
                    TextEntry::make('observacion')->label('Motivo del rechazo')->visible(fn ($state) => filled($state)),
                    TextEntry::make('usuario.nombre_completo')->label('Persona'),
                    TextEntry::make('usuario.ci_numero')
                        ->label('Carnet registrado')
                        ->formatStateUsing(fn (Documento $record) => trim(
                            $record->usuario->ci_numero.' '.$record->usuario->ci_complemento.' '.$record->usuario->ci_expedido))
                        ->placeholder('—'),
                    TextEntry::make('negocio.nombre')
                        ->label('Negocio')
                        ->url(fn (Documento $record) => $record->negocio_id
                            ? NegocioResource::getUrl('view', ['record' => $record->negocio_id]) : null)
                        ->placeholder('—'),
                    TextEntry::make('created_at')->label('Subido')->dateTime('d/m/Y H:i')->timezone(Estados::ZONA),
                    TextEntry::make('revisor.nombre_completo')->label('Revisado por')->placeholder('—'),
                ]),
        ])->columns(['default' => 1, 'lg' => 3]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListDocumentos::route('/'),
            'view' => ViewDocumento::route('/{record}'),
        ];
    }
}
