<?php

namespace App\Filament\Resources\Repartidores;

use App\Filament\Resources\Repartidores\Pages\ListRepartidores;
use App\Filament\Resources\Repartidores\Pages\ViewRepartidor;
use App\Filament\Resources\Repartidores\Schemas\RepartidorInfolist;
use App\Filament\Resources\Repartidores\Tables\RepartidoresTable;
use App\Models\Repartidor;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/** Repartidores registrados: el administrador revisa su vehículo y documentos y los aprueba. */
class RepartidorResource extends Resource
{
    protected static ?string $model = Repartidor::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedTruck;

    protected static string|UnitEnum|null $navigationGroup = 'Aprobaciones';

    protected static ?int $navigationSort = 2;

    protected static ?string $slug = 'repartidores';

    protected static ?string $modelLabel = 'repartidor';

    protected static ?string $pluralModelLabel = 'repartidores';

    /** Cuántos esperan revisión (número junto al menú). */
    public static function getNavigationBadge(): ?string
    {
        $pendientes = Repartidor::where('estado_verificacion', 'pendiente')->count();

        return $pendientes > 0 ? (string) $pendientes : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    // Se registran desde la app, no los crea el administrador.
    public static function canCreate(): bool
    {
        return false;
    }

    /** El repartidor no tiene nombre propio: se muestra el de la persona. */
    public static function getRecordTitle(?Model $record): string
    {
        return $record?->usuario?->nombre_completo ?? 'Repartidor';
    }

    public static function infolist(Schema $schema): Schema
    {
        return RepartidorInfolist::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return RepartidoresTable::configure($table);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListRepartidores::route('/'),
            'view' => ViewRepartidor::route('/{record}'),
        ];
    }
}
