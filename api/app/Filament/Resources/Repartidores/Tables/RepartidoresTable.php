<?php

namespace App\Filament\Resources\Repartidores\Tables;

use App\Filament\Acciones\AccionesRepartidor;
use App\Filament\Estados;
use App\Models\Repartidor;
use App\Models\Vehiculo;
use Filament\Actions\ActionGroup;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class RepartidoresTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['usuario', 'vehiculos.tipo']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('usuario.nombre')
                    ->label('Repartidor')
                    ->weight('bold')
                    ->formatStateUsing(fn (Repartidor $record) => $record->usuario?->nombre_completo)
                    ->description(fn (Repartidor $record) => $record->usuario?->email)
                    ->searchable(['nombre', 'apellido', 'email']),
                TextColumn::make('vehiculo')
                    ->label('Vehículo')
                    ->state(fn (Repartidor $record) => $record->vehiculos
                        ->map(fn (Vehiculo $v) => trim($v->tipo->nombre.' '.$v->placa))
                        ->join(', ') ?: null)
                    ->placeholder('Sin vehículo'),
                TextColumn::make('usuario.telefono')
                    ->label('Teléfono')
                    ->placeholder('—')
                    ->toggleable(),
                TextColumn::make('estado_verificacion')
                    ->label('Estado')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => Estados::REPARTIDOR[$state] ?? $state)
                    ->color(fn (string $state) => Estados::color($state)),
                TextColumn::make('created_at')
                    ->label('Registrado')
                    ->since()
                    ->timezone(Estados::ZONA)
                    ->sortable(),
            ])
            ->recordActions([
                ViewAction::make()->label('Revisar'),
                ActionGroup::make(AccionesRepartidor::todas()),
            ])
            ->emptyStateHeading('No hay repartidores en esta lista');
    }
}
