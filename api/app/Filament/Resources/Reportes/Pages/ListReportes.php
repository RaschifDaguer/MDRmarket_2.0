<?php

namespace App\Filament\Resources\Reportes\Pages;

use App\Filament\Resources\Reportes\ReporteResource;
use App\Models\Reporte;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Tabs\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListReportes extends ListRecords
{
    protected static string $resource = ReporteResource::class;

    public function getTabs(): array
    {
        return [
            'abiertos' => Tab::make('Abiertos')
                ->badge(Reporte::whereIn('estado', ['pendiente', 'en_revision'])->count() ?: null)
                ->modifyQueryUsing(fn (Builder $query) => $query->whereIn('estado', ['pendiente', 'en_revision'])),
            'cerrados' => Tab::make('Resueltos o descartados')
                ->modifyQueryUsing(fn (Builder $query) => $query->whereIn('estado', ['resuelto', 'descartado'])),
            'todos' => Tab::make('Todos'),
        ];
    }
}
