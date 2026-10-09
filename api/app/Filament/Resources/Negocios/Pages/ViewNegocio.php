<?php

namespace App\Filament\Resources\Negocios\Pages;

use App\Filament\Acciones\AccionesNegocio;
use App\Filament\Resources\Negocios\NegocioResource;
use Filament\Resources\Pages\ViewRecord;

class ViewNegocio extends ViewRecord
{
    protected static string $resource = NegocioResource::class;

    protected function getHeaderActions(): array
    {
        return AccionesNegocio::todas();
    }
}
