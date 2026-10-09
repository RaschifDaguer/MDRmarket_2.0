<?php

namespace App\Filament\Resources\Documentos\Pages;

use App\Filament\Acciones\AccionesDocumento;
use App\Filament\Resources\Documentos\DocumentoResource;
use Filament\Resources\Pages\ViewRecord;

class ViewDocumento extends ViewRecord
{
    protected static string $resource = DocumentoResource::class;

    protected function getHeaderActions(): array
    {
        return AccionesDocumento::todas();
    }
}
