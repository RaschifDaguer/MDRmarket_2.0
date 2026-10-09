<?php

namespace App\Filament\Resources\TarifasEnvio\Pages;

use App\Filament\Resources\TarifasEnvio\TarifaEnvioResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ManageRecords;

class ManageTarifasEnvio extends ManageRecords
{
    protected static string $resource = TarifaEnvioResource::class;

    protected function getHeaderActions(): array
    {
        return [CreateAction::make()->label('Nueva tarifa')];
    }
}
