<?php

namespace App\Filament\Resources\Negocios;

use App\Filament\Resources\Negocios\Pages\ListNegocios;
use App\Filament\Resources\Negocios\Pages\ViewNegocio;
use App\Filament\Resources\Negocios\Schemas\NegocioInfolist;
use App\Filament\Resources\Negocios\Tables\NegociosTable;
use App\Models\Negocio;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use UnitEnum;

/** Negocios registrados: el administrador los revisa y los aprueba. */
class NegocioResource extends Resource
{
    protected static ?string $model = Negocio::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBuildingStorefront;

    protected static string|UnitEnum|null $navigationGroup = 'Aprobaciones';

    protected static ?int $navigationSort = 1;

    protected static ?string $modelLabel = 'negocio';

    protected static ?string $pluralModelLabel = 'negocios';

    protected static ?string $recordTitleAttribute = 'nombre';

    /** Cuántos esperan revisión (número junto al menú). */
    public static function getNavigationBadge(): ?string
    {
        $pendientes = Negocio::where('estado_verificacion', 'pendiente')->count();

        return $pendientes > 0 ? (string) $pendientes : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    // Los negocios los registra el comerciante desde la app, no el administrador.
    public static function canCreate(): bool
    {
        return false;
    }

    public static function infolist(Schema $schema): Schema
    {
        return NegocioInfolist::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return NegociosTable::configure($table);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListNegocios::route('/'),
            'view' => ViewNegocio::route('/{record}'),
        ];
    }
}
