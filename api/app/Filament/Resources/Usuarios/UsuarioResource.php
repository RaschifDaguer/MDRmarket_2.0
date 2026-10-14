<?php

namespace App\Filament\Resources\Usuarios;

use App\Filament\Estados;
use App\Filament\Resources\Usuarios\Pages\ListUsuarios;
use App\Models\Usuario;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use UnitEnum;

/** Cuentas de la app: activar/desactivar y dar o quitar permiso de administrador. */
class UsuarioResource extends Resource
{
    protected static ?string $model = Usuario::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUsers;

    protected static string|UnitEnum|null $navigationGroup = 'Operación';

    protected static ?int $navigationSort = 2;

    protected static ?string $modelLabel = 'usuario';

    protected static ?string $pluralModelLabel = 'usuarios';

    public static function canCreate(): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->withCount(['negocios', 'pedidos']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('nombre')
                    ->label('Nombre')
                    ->formatStateUsing(fn (Usuario $record) => $record->nombre_completo)
                    ->description(fn (Usuario $record) => $record->email)
                    ->searchable(['nombre', 'apellido', 'email', 'ci_numero']),
                TextColumn::make('ci_numero')->label('Carnet')->placeholder('—')->toggleable(),
                TextColumn::make('telefono')->label('Teléfono')->placeholder('—')->toggleable(),
                TextColumn::make('negocios_count')->label('Negocios')->alignCenter(),
                TextColumn::make('pedidos_count')->label('Pedidos')->alignCenter(),
                IconColumn::make('es_admin')->label('Admin')->boolean()->alignCenter(),
                IconColumn::make('activo')->label('Activa')->boolean()->alignCenter(),
                TextColumn::make('created_at')
                    ->label('Registro')
                    ->date('d/m/Y')
                    ->timezone(Estados::ZONA)
                    ->sortable(),
            ])
            ->filters([
                TernaryFilter::make('es_admin')->label('Administradores'),
                TernaryFilter::make('activo')->label('Cuenta activa'),
            ])
            ->recordActions([
                ActionGroup::make([
                    static::accionActivar(),
                    static::accionAdmin(),
                ]),
            ]);
    }

    private static function accionActivar(): Action
    {
        return Action::make('activar')
            ->label(fn (Usuario $record) => $record->activo ? 'Desactivar cuenta' : 'Activar cuenta')
            ->icon(fn (Usuario $record) => $record->activo ? Heroicon::OutlinedNoSymbol : Heroicon::OutlinedCheckCircle)
            ->color(fn (Usuario $record) => $record->activo ? 'danger' : 'success')
            // Nadie se desactiva a sí mismo (se quedaría fuera del panel).
            ->hidden(fn (Usuario $record) => $record->is(auth()->user()))
            ->requiresConfirmation()
            ->modalDescription(fn (Usuario $record) => $record->activo
                ? 'No podrá iniciar sesión y se cerrarán sus sesiones abiertas.'
                : 'Podrá volver a iniciar sesión.')
            ->action(function (Usuario $record) {
                $record->forceFill(['activo' => ! $record->activo])->save();
                if (! $record->activo) {
                    $record->tokens()->delete();
                }
                Notification::make()->title($record->activo ? 'Cuenta activada' : 'Cuenta desactivada')->success()->send();
            });
    }

    private static function accionAdmin(): Action
    {
        return Action::make('admin')
            ->label(fn (Usuario $record) => $record->es_admin ? 'Quitar administrador' : 'Hacer administrador')
            ->icon(Heroicon::OutlinedShieldCheck)
            ->color('warning')
            ->hidden(fn (Usuario $record) => $record->is(auth()->user()))
            ->requiresConfirmation()
            ->modalDescription(fn (Usuario $record) => $record->es_admin
                ? 'Ya no podrá entrar a este panel.'
                : 'Podrá entrar a este panel, aprobar negocios y documentos y cambiar la configuración.')
            ->action(function (Usuario $record) {
                $record->forceFill(['es_admin' => ! $record->es_admin])->save();
                Notification::make()->title('Permiso actualizado')->success()->send();
            });
    }

    public static function getPages(): array
    {
        return [
            'index' => ListUsuarios::route('/'),
        ];
    }
}
