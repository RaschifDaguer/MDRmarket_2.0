<?php

namespace App\Filament\Resources\Reportes;

use App\Filament\Estados;
use App\Filament\Resources\Reportes\Pages\ListReportes;
use App\Models\Notificacion;
use App\Models\Reporte;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use UnitEnum;

/**
 * Problemas que reportan los usuarios ("Hubo un problema" con la tienda o el
 * repartidor de un pedido). El admin los revisa y los marca como resueltos
 * (o descartados); quien reportó recibe un aviso con la respuesta.
 */
class ReporteResource extends Resource
{
    private const GRAVEDAD = ['alta' => 'danger', 'media' => 'warning', 'baja' => 'gray'];

    protected static ?string $model = Reporte::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedFlag;

    protected static string|UnitEnum|null $navigationGroup = 'Operación';

    protected static ?int $navigationSort = 3;

    protected static ?string $modelLabel = 'reporte';

    protected static ?string $pluralModelLabel = 'reportes';

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getNavigationBadge(): ?string
    {
        $abiertos = Reporte::whereIn('estado', ['pendiente', 'en_revision'])->count();

        return $abiertos ? (string) $abiertos : null;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['motivo', 'reportante', 'negocio', 'repartidorUsuario', 'producto', 'usuario']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('id')->label('#')->sortable(),
                TextColumn::make('created_at')->label('Fecha')->dateTime('d/m/Y H:i')->timezone(Estados::ZONA)->sortable(),
                TextColumn::make('tipo')
                    ->label('Sobre')
                    ->formatStateUsing(fn (Reporte $record) => $record->objetivoTexto())
                    ->wrap(),
                TextColumn::make('motivo.nombre')
                    ->label('Motivo')
                    ->badge()
                    ->color(fn (Reporte $record) => self::GRAVEDAD[$record->motivo?->gravedad] ?? 'gray')
                    ->wrap(),
                TextColumn::make('descripcion')->label('Qué pasó')->limit(80)->wrap()->placeholder('—'),
                TextColumn::make('reportante.nombre')
                    ->label('Reportó')
                    ->formatStateUsing(fn (Reporte $record) => $record->reportante?->nombre_completo)
                    ->searchable(['nombre', 'apellido', 'email']),
                TextColumn::make('pedido_id')->label('Pedido')->prefix('#')->placeholder('—'),
                TextColumn::make('estado')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => Reporte::ESTADOS[$state] ?? $state)
                    ->color(fn (string $state) => match ($state) {
                        'pendiente' => 'warning',
                        'en_revision' => 'info',
                        'resuelto' => 'success',
                        default => 'gray',
                    }),
                TextColumn::make('resolucion')->label('Respuesta')->limit(60)->wrap()->placeholder('—')->toggleable(),
            ])
            ->filters([
                SelectFilter::make('estado')->label('Estado')->options(Reporte::ESTADOS),
                SelectFilter::make('tipo')->label('Sobre')->options(Reporte::TIPOS),
            ])
            ->recordActions([
                static::accionCerrar('resolver', 'Marcar resuelto', 'resuelto', 'success', Heroicon::OutlinedCheckCircle),
                static::accionCerrar('descartar', 'Descartar', 'descartado', 'gray', Heroicon::OutlinedXCircle),
            ]);
    }

    /** Cierra el reporte (resuelto o descartado) con la respuesta del admin, y avisa a quien reportó. */
    public static function accionCerrar(string $nombre, string $etiqueta, string $estado, string $color, Heroicon $icono): Action
    {
        return Action::make($nombre)
            ->label($etiqueta)
            ->icon($icono)
            ->color($color)
            ->visible(fn (Reporte $record) => $record->estaAbierto())
            ->modalHeading(fn (Reporte $record) => "$etiqueta el reporte #{$record->id}")
            ->modalDescription('Quien reportó recibe un aviso con esta respuesta.')
            ->schema([
                Textarea::make('resolucion')
                    ->label('Respuesta')
                    ->placeholder($estado === 'resuelto' ? 'Ej.: hablamos con la tienda y te devolvemos el producto faltante.' : 'Ej.: revisamos el pedido y no encontramos el problema.')
                    ->required()
                    ->maxLength(500),
            ])
            ->modalSubmitActionLabel($etiqueta)
            ->action(function (Reporte $record, array $data) use ($estado) {
                $record->forceFill([
                    'estado' => $estado,
                    'resolucion' => $data['resolucion'],
                    'revisado_por' => auth()->id(),
                    'revisado_en' => now(),
                ])->save();
                Notificacion::avisar($record->reportante_id, 'reporte_'.$estado,
                    $estado === 'resuelto' ? 'Revisamos tu reporte' : 'Cerramos tu reporte',
                    $data['resolucion'], $record->pedido_id);
                Notification::make()->title($estado === 'resuelto' ? 'Reporte resuelto' : 'Reporte descartado')->success()->send();
            });
    }

    public static function getPages(): array
    {
        return [
            'index' => ListReportes::route('/'),
        ];
    }
}
