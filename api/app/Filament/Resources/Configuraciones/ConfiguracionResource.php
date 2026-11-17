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
 * Parámetros del negocio (tabla `configuracion`). Solo los ve y edita el admin
 * (el panel entero es solo para administradores). Se muestran los que tiene
 * sentido cambiar; las coordenadas del centro y la zona horaria quedan fijas.
 * Cada valor se valida según su tipo (entero o decimal) y su rango.
 */
class ConfiguracionResource extends Resource
{
    /** Clave => [mínimo, máximo, unidad]. El orden es el de la lista. */
    public const EDITABLES = [
        'comision_plataforma_pct' => [0, 100, '%'],
        'tarifa_servicio' => [0, 1000, 'Bs'],
        'minutos_para_aceptar' => [1, 60, 'min'],
        'minutos_para_pagar_qr' => [1, 120, 'min'],
        'minutos_listo_sin_repartidor' => [5, 1440, 'min'],
        'umbral_poco_stock' => [0, 1000, 'u.'],
        'radio_busqueda_repartidor_km' => [1, 50, 'km'],
        'velocidad_promedio_kmh' => [5, 60, 'km/h'],
        'factor_ruta' => [1, 3, '×'],
    ];

    protected static ?string $model = Configuracion::class;

    protected static ?string $slug = 'configuracion';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCog6Tooth;

    protected static string|UnitEnum|null $navigationGroup = 'Configuración';

    protected static ?int $navigationSort = 2;

    protected static ?string $modelLabel = 'parámetro';

    protected static ?string $pluralModelLabel = 'parámetros';

    public static function getEloquentQuery(): Builder
    {
        $claves = array_keys(self::EDITABLES);

        return parent::getEloquentQuery()
            ->whereIn('clave', $claves)
            ->orderByRaw('FIELD(clave, '.implode(',', array_fill(0, count($claves), '?')).')', $claves);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    /** Reglas del valor según el tipo de la fila (int o decimal) y su rango. */
    public static function reglas(?Configuracion $parametro): array
    {
        [$minimo, $maximo] = self::EDITABLES[$parametro?->clave] ?? [0, 1000000];

        return [
            $parametro?->tipo === 'int' ? 'integer' : 'numeric',
            "min:$minimo",
            "max:$maximo",
        ];
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('valor')
                ->label(fn (?Configuracion $record) => $record?->descripcion ?? 'Valor')
                ->numeric()
                ->step(fn (?Configuracion $record) => $record?->tipo === 'int' ? 1 : 'any')
                ->suffix(fn (?Configuracion $record) => self::EDITABLES[$record?->clave][2] ?? null)
                ->helperText(fn (?Configuracion $record) => self::ayuda($record))
                ->rules(fn (?Configuracion $record) => self::reglas($record))
                ->validationMessages([
                    'integer' => 'Escribe un número entero, sin decimales.',
                    'numeric' => 'Escribe un número.',
                ])
                ->required(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('descripcion')->label('Parámetro')->wrap(),
                TextColumn::make('valor')
                    ->weight('bold')
                    ->formatStateUsing(fn (string $state, Configuracion $record) => trim($state.' '.(self::EDITABLES[$record->clave][2] ?? ''))),
                TextColumn::make('tipo')
                    ->label('Tipo')
                    ->formatStateUsing(fn (string $state) => $state === 'int' ? 'Entero' : 'Decimal'),
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

    private static function ayuda(?Configuracion $parametro): ?string
    {
        if (! $parametro) {
            return null;
        }
        [$minimo, $maximo] = self::EDITABLES[$parametro->clave] ?? [null, null];
        $tipo = $parametro->tipo === 'int' ? 'Número entero' : 'Número (puede llevar decimales)';

        return $minimo === null ? $tipo : "$tipo, entre $minimo y $maximo.";
    }
}
