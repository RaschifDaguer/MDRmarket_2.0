<?php

namespace App\Filament\Resources\Negocios\Pages;

use App\Filament\Estados;
use App\Filament\Resources\Negocios\NegocioResource;
use App\Models\Negocio;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Tabs\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListNegocios extends ListRecords
{
    protected static string $resource = NegocioResource::class;

    /** Una pestaña por estado; abre en "En revisión", que es lo que hay que atender. */
    public function getTabs(): array
    {
        $tabs = [];
        foreach (Estados::NEGOCIO as $estado => $texto) {
            $tabs[$estado] = Tab::make($texto)
                ->badge(Negocio::where('estado_verificacion', $estado)->count() ?: null)
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
