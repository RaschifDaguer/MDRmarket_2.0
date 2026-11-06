<?php

namespace App\Filament\Resources\Repartidores\Pages;

use App\Filament\Acciones\AccionesRepartidor;
use App\Filament\Resources\Repartidores\RepartidorResource;
use Filament\Resources\Pages\ViewRecord;

class ViewRepartidor extends ViewRecord
{
    protected static string $resource = RepartidorResource::class;

    protected function getHeaderActions(): array
    {
        return AccionesRepartidor::todas();
    }
}
