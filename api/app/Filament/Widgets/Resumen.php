<?php

namespace App\Filament\Widgets;

use App\Filament\Resources\Documentos\DocumentoResource;
use App\Filament\Resources\Negocios\NegocioResource;
use App\Filament\Resources\Pedidos\PedidoResource;
use App\Models\Documento;
use App\Models\Negocio;
use App\Models\Pedido;
use App\Models\Usuario;
use Carbon\CarbonImmutable;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

/** Tarjetas del inicio del panel: lo que hay que atender y cómo va el día. */
class Resumen extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        // "Hoy" en hora de Bolivia, pasado a UTC (así se guarda en la base).
        $hoy = CarbonImmutable::now('America/La_Paz')->startOfDay()->utc();

        $negocios = Negocio::where('estado_verificacion', 'pendiente')->count();
        $documentos = Documento::solicitudes()->where('estado', 'pendiente')->count();
        $pedidosHoy = Pedido::where('created_at', '>=', $hoy)->count();
        $ventasHoy = Pedido::where('estado', 'entregado')->where('entregado_en', '>=', $hoy)->sum('total');

        return [
            Stat::make('Negocios por revisar', $negocios)
                ->color($negocios > 0 ? 'warning' : 'success')
                ->description($negocios > 0 ? 'Toca para revisarlos' : 'Todo al día')
                ->url(NegocioResource::getUrl()),
            Stat::make('Documentos por revisar', $documentos)
                ->color($documentos > 0 ? 'warning' : 'success')
                ->description($documentos > 0 ? 'Carnet, licencia…' : 'Todo al día')
                ->url(DocumentoResource::getUrl()),
            Stat::make('Pedidos de hoy', $pedidosHoy)
                ->description('Bs '.number_format((float) $ventasHoy, 2, ',', '.').' entregados')
                ->url(PedidoResource::getUrl()),
            Stat::make('Usuarios', Usuario::count())
                ->description(Negocio::where('estado_verificacion', 'aprobado')->count().' negocios activos'),
        ];
    }
}
