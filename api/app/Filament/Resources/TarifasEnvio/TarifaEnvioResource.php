<?php

namespace App\Filament\Resources\TarifasEnvio;

use App\Filament\Resources\TarifasEnvio\Pages\ManageTarifasEnvio;
use App\Models\TarifaEnvio;
use BackedEnum;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Table;
use UnitEnum;

/**
 * Precio del envío por distancia: "hasta X km cuesta Y Bs". Se usa el rango
 * más chico que cubra la distancia; más allá del último, no hay cobertura.
 */
class TarifaEnvioResource extends Resource
{
    protected static ?string $model = TarifaEnvio::class;

    protected static ?string $slug = 'tarifas-envio';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedTruck;

    protected static string|UnitEnum|null $navigationGroup = 'Configuración';

    protected static ?int $navigationSort = 1;

    protected static ?string $modelLabel = 'tarifa de envío';

    protected static ?string $pluralModelLabel = 'tarifas de envío';

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('categoria_vehiculo_id')
                ->label('Vehículo')
                ->relationship('categoriaVehiculo', 'nombre')
                ->default(1)
                ->required(),
            TextInput::make('km_hasta')->label('Hasta (km)')->numeric()->minValue(0.1)->required(),
            TextInput::make('precio')->label('Precio (Bs)')->numeric()->minValue(0)->required(),
            Toggle::make('activo')->default(true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with('categoriaVehiculo'))
            ->defaultSort(fn ($query) => $query->orderBy('categoria_vehiculo_id')->orderBy('km_hasta'))
            ->columns([
                TextColumn::make('categoriaVehiculo.nombre')->label('Vehículo'),
                TextColumn::make('km_hasta')->label('Hasta')->suffix(' km'),
                TextColumn::make('precio')->money('BOB'),
                ToggleColumn::make('activo'),
            ])
            ->recordActions([EditAction::make(), DeleteAction::make()])
            ->paginated(false);
    }

    public static function getPages(): array
    {
        return [
            'index' => ManageTarifasEnvio::route('/'),
        ];
    }
}
