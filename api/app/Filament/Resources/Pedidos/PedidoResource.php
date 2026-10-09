<?php

namespace App\Filament\Resources\Pedidos;

use App\Filament\Estados;
use App\Filament\Resources\Pedidos\Pages\ListPedidos;
use App\Filament\Resources\Pedidos\Pages\ViewPedido;
use App\Models\Pedido;
use App\Support\FlujoPedido;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\Textarea;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use UnitEnum;

/** Todos los pedidos: para seguirlos y, si hace falta, cancelarlos. */
class PedidoResource extends Resource
{
    protected static ?string $model = Pedido::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShoppingBag;

    protected static string|UnitEnum|null $navigationGroup = 'Operación';

    protected static ?int $navigationSort = 1;

    protected static ?string $modelLabel = 'pedido';

    protected static ?string $pluralModelLabel = 'pedidos';

    public static function canCreate(): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['negocio', 'comprador']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('id')->label('#')->sortable(),
                TextColumn::make('negocio.nombre')->label('Negocio')->searchable(),
                TextColumn::make('comprador.nombre')
                    ->label('Cliente')
                    ->formatStateUsing(fn (Pedido $record) => $record->comprador?->nombre_completo)
                    ->searchable(['nombre', 'apellido', 'email']),
                TextColumn::make('estado')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => Estados::PEDIDO[$state] ?? $state)
                    ->color(fn (string $state) => Estados::color($state)),
                TextColumn::make('total')->money('BOB')->alignEnd(),
                TextColumn::make('metodo_pago')->label('Pago')->formatStateUsing(fn (string $state) => ucfirst($state)),
                TextColumn::make('created_at')
                    ->label('Fecha')
                    ->dateTime('d/m/Y H:i')
                    ->timezone(Estados::ZONA)
                    ->sortable(),
            ])
            ->recordActions([
                ViewAction::make()->label('Ver'),
                static::accionCancelar(),
            ]);
    }

    public static function accionCancelar(): Action
    {
        return Action::make('cancelar')
            ->label('Cancelar')
            ->icon(Heroicon::OutlinedXCircle)
            ->color('danger')
            ->visible(fn (Pedido $record) => FlujoPedido::siguientes($record, 'admin') !== [])
            ->modalHeading(fn (Pedido $record) => "Cancelar el pedido #{$record->id}")
            ->modalDescription('Se avisará al cliente y se devolverá el stock al negocio.')
            ->schema([Textarea::make('motivo')->label('Motivo')->required()->maxLength(255)])
            ->modalSubmitActionLabel('Cancelar pedido')
            ->action(function (Pedido $record, array $data) {
                FlujoPedido::cambiar($record, 'cancelado', auth()->user(), 'admin', $data['motivo']);
                Notification::make()->title('Pedido cancelado')->success()->send();
            });
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Pedido')
                ->columns(2)
                ->schema([
                    TextEntry::make('estado')
                        ->badge()
                        ->formatStateUsing(fn (string $state) => Estados::PEDIDO[$state] ?? $state)
                        ->color(fn (string $state) => Estados::color($state)),
                    TextEntry::make('created_at')->label('Fecha')->dateTime('d/m/Y H:i')->timezone(Estados::ZONA),
                    TextEntry::make('negocio.nombre')->label('Negocio'),
                    TextEntry::make('comprador.nombre_completo')->label('Cliente'),
                    TextEntry::make('direccion_entrega')->label('Entregar en')->columnSpanFull(),
                    TextEntry::make('referencia_entrega')->label('Referencia')->placeholder('—'),
                    TextEntry::make('notas')->placeholder('—'),
                    TextEntry::make('metodo_pago')->label('Pago')->formatStateUsing(fn (string $state) => ucfirst($state)),
                    TextEntry::make('estado_pago')->label('Estado del pago'),
                    TextEntry::make('motivo_cancelacion')->label('Motivo de cancelación')
                        ->visible(fn ($state) => filled($state))->columnSpanFull(),
                ]),
            Section::make('Montos')
                ->columns(2)
                ->schema([
                    TextEntry::make('subtotal')->money('BOB'),
                    TextEntry::make('costo_envio')->label('Envío')->money('BOB'),
                    TextEntry::make('tarifa_servicio')->label('Servicio')->money('BOB'),
                    TextEntry::make('total')->money('BOB')->weight('bold'),
                    TextEntry::make('comision_plataforma')->label('Comisión (al negocio)')->money('BOB'),
                    TextEntry::make('distancia_km')->label('Distancia')->suffix(' km')->placeholder('—'),
                ]),
            Section::make('Productos')
                ->columnSpanFull()
                ->schema([
                    RepeatableEntry::make('items')
                        ->hiddenLabel()
                        ->columns(4)
                        ->schema([
                            TextEntry::make('producto_nombre')->label('Producto')->columnSpan(2),
                            TextEntry::make('cantidad'),
                            TextEntry::make('subtotal')->money('BOB'),
                        ]),
                ]),
            Section::make('Historial')
                ->columnSpanFull()
                ->collapsed()
                ->schema([
                    RepeatableEntry::make('historial')
                        ->hiddenLabel()
                        ->columns(3)
                        ->schema([
                            TextEntry::make('estado_nuevo')
                                ->label('Estado')
                                ->formatStateUsing(fn (string $state) => Estados::PEDIDO[$state] ?? $state),
                            TextEntry::make('rol')->label('Quién'),
                            TextEntry::make('created_at')->label('Cuándo')->dateTime('d/m/Y H:i')->timezone(Estados::ZONA),
                        ]),
                ]),
        ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListPedidos::route('/'),
            'view' => ViewPedido::route('/{record}'),
        ];
    }
}
