<?php

namespace App\Filament\Resources\Negocios\Tables;

use App\Filament\Acciones\AccionesNegocio;
use App\Filament\Estados;
use App\Models\Negocio;
use App\Support\Archivos;
use Filament\Actions\ActionGroup;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class NegociosTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['usuario', 'categoria']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                ImageColumn::make('logo_url')
                    ->label('')
                    ->state(fn (Negocio $record) => Archivos::url($record->logo_url))
                    ->square()
                    ->imageSize(48),
                TextColumn::make('nombre')
                    ->label('Negocio')
                    ->searchable()
                    ->weight('bold')
                    ->description(fn (Negocio $record) => $record->categoria?->nombre),
                TextColumn::make('usuario.nombre')
                    ->label('Dueño')
                    ->formatStateUsing(fn (Negocio $record) => $record->usuario?->nombre_completo)
                    ->description(fn (Negocio $record) => $record->usuario?->email)
                    ->searchable(['nombre', 'apellido', 'email']),
                TextColumn::make('direccion')
                    ->label('Dirección')
                    ->limit(40)
                    ->toggleable(),
                TextColumn::make('estado_verificacion')
                    ->label('Estado')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => Estados::NEGOCIO[$state] ?? $state)
                    ->color(fn (string $state) => Estados::color($state)),
                TextColumn::make('created_at')
                    ->label('Registrado')
                    ->since()
                    ->timezone(Estados::ZONA)
                    ->sortable(),
            ])
            ->recordActions([
                ViewAction::make()->label('Revisar'),
                ActionGroup::make(AccionesNegocio::todas()),
            ])
            ->emptyStateHeading('No hay negocios en esta lista');
    }
}
