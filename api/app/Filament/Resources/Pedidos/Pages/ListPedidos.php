<?php

namespace App\Filament\Resources\Pedidos\Pages;

use App\Filament\Resources\Pedidos\PedidoResource;
use App\Models\Pedido;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Tabs\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListPedidos extends ListRecords
{
    protected static string $resource = PedidoResource::class;

    public function getTabs(): array
    {
        return [
            'activos' => Tab::make('En curso')
                ->badge(Pedido::whereIn('estado', Pedido::ESTADOS_ACTIVOS)->count() ?: null)
                ->modifyQueryUsing(fn (Builder $query) => $query->whereIn('estado', Pedido::ESTADOS_ACTIVOS)),
            'entregados' => Tab::make('Entregados')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('estado', 'entregado')),
            'cancelados' => Tab::make('Cancelados o rechazados')
                ->modifyQueryUsing(fn (Builder $query) => $query->whereIn('estado', ['cancelado', 'rechazado'])),
            'todos' => Tab::make('Todos'),
        ];
    }
}
