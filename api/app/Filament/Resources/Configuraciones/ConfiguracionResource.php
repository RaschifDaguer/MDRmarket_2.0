<?php

namespace App\Filament\Resources\Configuraciones;

use App\Filament\Resources\Configuraciones\Pages\ManageConfiguraciones;
use App\Models\Configuracion;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use UnitEnum;

/**
 * Parámetros del negocio (tabla `configuracion`). Solo se muestran los que
 * tiene sentido cambiar desde el panel; las coordenadas del centro y la zona
 * horaria quedan fijas.
 */
class ConfiguracionResource extends Resource
{
    public const EDITABLES = ['tarifa_servicio', 'comision_plataforma_pct', 'factor_ruta', 'radio_busqueda_repartidor_km'];

    protected static ?string $model = Configuracion::class;

    protected static ?string $slug = 'configuracion';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCog6Tooth;

    protected static string|UnitEnum|null $navigationGroup = 'Configuración';

    protected static ?int $navigationSort = 2;

    protected static ?string $modelLabel = 'parámetro';

    protected static ?string $pluralModelLabel = 'parámetros';

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->whereIn('clave', self::EDITABLES);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('valor')
                ->label(fn (?Configuracion $record) => $record?->descripcion ?? 'Valor')
                ->numeric()
                ->minValue(0)
                ->required(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('descripcion')->label('Parámetro')->wrap(),
                TextColumn::make('valor')->weight('bold'),
            ])
            ->recordActions([EditAction::make()])
            ->paginated(false);
    }

    public static function getPages(): array
    {
        return [
            'index' => ManageConfiguraciones::route('/'),
        ];
    }
}
