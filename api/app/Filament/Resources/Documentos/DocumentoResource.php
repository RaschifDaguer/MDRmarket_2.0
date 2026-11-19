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
use Filament\Infolists\Components\ViewEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Callout;
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

    protected static ?int $navigationSort = 3;

    protected static ?string $modelLabel = 'documento';

    protected static ?string $pluralModelLabel = 'documentos';

    public static function getNavigationBadge(): ?string
    {
        $pendientes = Documento::solicitudes()->where('estado', 'pendiente')->count();

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
            // Una fila por solicitud (los dos lados del carnet van juntos).
            ->modifyQueryUsing(fn ($query) => $query->solicitudes()->with(['usuario', 'tipo', 'negocio']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('usuario.nombre')
                    ->label('Persona')
                    ->formatStateUsing(fn (Documento $record) => $record->usuario?->nombre_completo)
                    ->description(fn (Documento $record) => $record->usuario?->email)
                    ->searchable(['nombre', 'apellido', 'email']),
                TextColumn::make('tipo.nombre')
                    ->label('Documento')
                    ->formatStateUsing(fn (Documento $record) => $record->nombreSolicitud()),
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

    /** Permisos con cartón de la Alcaldía o del SEDES: suelen traer un QR para verificarlos. */
    private const CON_QR = ['licencia_funcionamiento', 'autorizacion_alcohol', 'resolucion_sedes'];

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            // Qué revisar en este tipo de documento (ej. el rubro de la licencia).
            Callout::make('Antes de aprobar')
                ->description(fn (Documento $record) => $record->tipo?->instrucciones_revision)
                ->warning()
                ->visible(fn (Documento $record) => filled($record->tipo?->instrucciones_revision))
                ->columnSpanFull(),
            // La identidad muestra el carnet (los dos lados) y la selfie juntos;
            // otros documentos, su única foto.
            Section::make('Fotos')
                ->description(fn (Documento $record) => $record->documentosDeLaSolicitud()->contains(fn (Documento $d) => $d->lado() === 'rostro')
                    ? 'Revisa que la cara de la selfie sea la misma persona de la foto del carnet.' : null)
                ->columnSpan(['lg' => 2])
                ->columns(['default' => 1, 'md' => 2, 'xl' => 3])
                ->schema([
                    static::foto('foto_1', 0),
                    static::foto('foto_2', 1),
                    static::foto('foto_3', 2),
                ]),
            Section::make('Datos')
                ->columnSpan(1)
                ->schema([
                    TextEntry::make('tipo.nombre')
                        ->label('Documento')
                        ->weight('bold')
                        ->formatStateUsing(fn (Documento $record) => $record->nombreSolicitud()),
                    TextEntry::make('estado')
                        ->badge()
                        ->formatStateUsing(fn (string $state) => Estados::DOCUMENTO[$state] ?? $state)
                        ->color(fn (string $state) => Estados::color($state)),
                    TextEntry::make('observacion')->label('Motivo del rechazo')->visible(fn ($state) => filled($state)),
                    TextEntry::make('numero')->label('Número')->visible(fn ($state) => filled($state)),
                    // Licencias y permisos: leer el QR para verificarlos en la página de la Alcaldía.
                    ViewEntry::make('qr')
                        ->label('Verificar con el QR')
                        ->view('filament.leer-qr')
                        ->state(fn (Documento $record) => route('panel.documento.archivo', $record))
                        ->visible(fn (Documento $record) => in_array($record->tipo?->codigo, self::CON_QR, true) && $record->esImagen()),
                    TextEntry::make('qr_pdf')
                        ->label('Verificar con el QR')
                        ->state('Es un PDF: ábrelo y escanea el QR con la cámara de tu celular.')
                        ->visible(fn (Documento $record) => in_array($record->tipo?->codigo, self::CON_QR, true) && ! $record->esImagen()),
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

    /** Foto de la solicitud en la posición dada (anverso, reverso, selfie; o la única). */
    private static function foto(string $nombre, int $posicion): ImageEntry
    {
        $documento = fn (Documento $record): ?Documento => $record->documentosDeLaSolicitud()->get($posicion);

        return ImageEntry::make($nombre)
            ->label(fn (Documento $record) => $documento($record)?->tipo->nombre)
            ->state(fn (Documento $record) => ($d = $documento($record)) && $d->esImagen()
                ? route('panel.documento.archivo', $d) : null)
            ->url(fn (Documento $record) => ($d = $documento($record)) ? route('panel.documento.archivo', $d) : null)
            ->openUrlInNewTab()
            ->imageHeight(280)
            ->visible(fn (Documento $record) => $documento($record) !== null)
            ->placeholder('Es un PDF: haz clic para abrirlo.');
    }

    public static function getPages(): array
    {
        return [
            'index' => ListDocumentos::route('/'),
            'view' => ViewDocumento::route('/{record}'),
        ];
    }
}
