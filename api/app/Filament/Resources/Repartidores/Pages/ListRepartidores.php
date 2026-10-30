<?php

namespace App\Filament\Resources\Repartidores\Pages;

use App\Filament\Estados;
use App\Filament\Resources\Repartidores\RepartidorResource;
use App\Models\Repartidor;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Tabs\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListRepartidores extends ListRecords
{
    protected static string $resource = RepartidorResource::class;

    /** Una pestaña por estado; abre en "En revisión", que es lo que hay que atender. */
    public function getTabs(): array
    {
        $tabs = [];
        foreach (Estados::REPARTIDOR as $estado => $texto) {
            $tabs[$estado] = Tab::make($texto)
                ->badge(Repartidor::where('estado_verificacion', $estado)->count() ?: null)
                ->modifyQueryUsing(fn (Builder $query) => $query->where('estado_verificacion', $estado));
        }
        $tabs['todos'] = Tab::make('Todos');

        return $tabs;
    }

    public function getDefaultActiveTab(): string|int|null
    {
        return 'pendiente';
    }
}
