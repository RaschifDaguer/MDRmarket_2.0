<?php

namespace App\Filament\Resources\Documentos\Pages;

use App\Filament\Estados;
use App\Filament\Resources\Documentos\DocumentoResource;
use App\Models\Documento;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Tabs\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListDocumentos extends ListRecords
{
    protected static string $resource = DocumentoResource::class;

    public function getTabs(): array
    {
        $tabs = [];
        foreach (Estados::DOCUMENTO as $estado => $texto) {
            $tabs[$estado] = Tab::make($texto)
                ->badge(Documento::solicitudes()->where('estado', $estado)->count() ?: null)
                ->modifyQueryUsing(fn (Builder $query) => $query->where('estado', $estado));
        }
        $tabs['todos'] = Tab::make('Todos');

        return $tabs;
    }

    public function getDefaultActiveTab(): string|int|null
    {
        return 'pendiente';
    }
}
