<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Configuracion;
use App\Models\Pedido;
use App\Models\UbicacionRepartidor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Rastreo del pedido en el mapa (primera versión: la app consulta cada pocos
 * segundos). El repartidor manda su GPS mientras lleva un pedido y el cliente
 * (o el negocio) ve dónde está y cuánto falta.
 */
class RastreoController extends Controller
{
    /** No se acepta otra posición del mismo repartidor antes de estos segundos. */
    public const SEGUNDOS_ENTRE_POSICIONES = 3;

    /** Velocidad promedio de una moto en la ciudad, si no está en `configuracion`. */
    public const VELOCIDAD_KMH = 25;

    /**
     * POST /api/repartidor/ubicacion — el repartidor manda su GPS. Solo si
     * tiene un pedido aceptado o en camino; se guarda en ubicacion_repartidor
     * (ligado a ese pedido) y como su posición actual.
     */
    public function ubicacion(Request $request): JsonResponse
    {
        $repartidor = $request->user()->repartidor()->first();
        abort_unless($repartidor, 403, 'Todavía no te registraste como repartidor.');

        $datos = $request->validate([
            'latitud' => ['required', 'numeric', 'between:-90,90'],
            'longitud' => ['required', 'numeric', 'between:-180,180'],
        ], [
            'latitud.*' => 'La ubicación no es válida.',
            'longitud.*' => 'La ubicación no es válida.',
        ]);
        // 0,0 es lo que mandan algunos GPS cuando todavía no tienen señal.
        if ((float) $datos['latitud'] === 0.0 && (float) $datos['longitud'] === 0.0) {
            throw ValidationException::withMessages(['latitud' => 'La ubicación no es válida.']);
        }

        $pedido = $repartidor->pedidos()->whereIn('estado', Pedido::ESTADOS_REPARTO)->latest('id')->first();
        if (! $pedido) {
            return response()->json(['message' => 'Solo se manda la ubicación mientras llevas un pedido.'], 422);
        }

        $ultima = UbicacionRepartidor::where('repartidor_id', $repartidor->usuario_id)->max('registrado_en');
        if ($ultima && now()->diffInSeconds($ultima, true) < self::SEGUNDOS_ENTRE_POSICIONES) {
            return response()->json(
                ['message' => 'Espera unos segundos antes de mandar otra ubicación.'],
                429,
                ['Retry-After' => self::SEGUNDOS_ENTRE_POSICIONES]
            );
        }

        DB::transaction(function () use ($repartidor, $pedido, $datos) {
            UbicacionRepartidor::create([
                'repartidor_id' => $repartidor->usuario_id,
                'pedido_id' => $pedido->id,
                'latitud' => $datos['latitud'],
                'longitud' => $datos['longitud'],
                'registrado_en' => now(),
            ]);
            $repartidor->forceFill([
                'latitud_actual' => $datos['latitud'],
                'longitud_actual' => $datos['longitud'],
                'ubicacion_actualizada_en' => now(),
            ])->save();
        });

        return response()->json(['pedido_id' => $pedido->id, 'guardada' => true], 201);
    }

    /**
     * GET /api/pedidos/{pedido}/seguimiento — lo ven el comprador y el negocio.
     * La posición del repartidor solo se entrega mientras lleva el pedido
     * (aceptado o en camino): al entregarlo o cancelarlo ya no se ve dónde está.
     */
    public function seguimiento(Request $request, Pedido $pedido): JsonResponse
    {
        $usuarioId = (int) $request->user()->id;
        $pedido->load(['negocio', 'repartidor', 'vehiculo.tipo']);
        abort_unless(in_array($usuarioId, [(int) $pedido->comprador_id, (int) $pedido->negocio->usuario_id], true), 404);

        $enReparto = $pedido->repartidor_id !== null && in_array($pedido->estado, Pedido::ESTADOS_REPARTO, true);
        $posicion = $enReparto ? $this->ultimaPosicion($pedido) : null;

        // Lo que falta: si ya lo recogió, hasta la casa; si no, pasar por el negocio y después a la casa.
        $km = null;
        if ($posicion) {
            $destino = [$pedido->latitud_entrega, $pedido->longitud_entrega];
            $km = $pedido->estado === 'en_camino'
                ? $this->km([$posicion['latitud'], $posicion['longitud']], $destino)
                : $this->km([$posicion['latitud'], $posicion['longitud']], [$pedido->negocio->latitud, $pedido->negocio->longitud])
                    + $this->km([$pedido->negocio->latitud, $pedido->negocio->longitud], $destino);
            $km = round($km * (float) Configuracion::valor('factor_ruta', 1.3), 2);
        }
        $velocidad = (float) Configuracion::valor('velocidad_promedio_kmh', self::VELOCIDAD_KMH);

        return response()->json([
            'pedido_id' => $pedido->id,
            'estado' => $pedido->estado,
            'repartidor' => $enReparto && $pedido->repartidor ? [
                'nombre' => $pedido->repartidor->nombre_completo,
                'vehiculo' => $pedido->vehiculo?->tipo?->nombre,
                'placa' => $pedido->vehiculo?->placa,
            ] : null,
            'ubicacion_repartidor' => $posicion,
            'negocio' => [
                'nombre' => $pedido->negocio->nombre,
                'latitud' => $pedido->negocio->latitud,
                'longitud' => $pedido->negocio->longitud,
            ],
            'destino' => [
                'direccion' => $pedido->direccion_entrega,
                'latitud' => $pedido->latitud_entrega,
                'longitud' => $pedido->longitud_entrega,
            ],
            'distancia_km' => $km,
            'tiempo_estimado_min' => $km !== null ? max(1, (int) ceil($km / max($velocidad, 1) * 60)) : null,
            'velocidad_kmh' => $velocidad,
        ]);
    }

    /** Último punto que mandó para este pedido (o su posición al aceptarlo, si todavía no mandó). */
    private function ultimaPosicion(Pedido $pedido): ?array
    {
        $punto = UbicacionRepartidor::where('pedido_id', $pedido->id)->latest('registrado_en')->latest('id')->first();
        if ($punto) {
            return $this->posicion($punto->latitud, $punto->longitud, $punto->registrado_en);
        }

        $repartidor = $pedido->repartidor?->repartidor;
        if ($repartidor?->latitud_actual !== null && $repartidor->ubicacion_actualizada_en) {
            return $this->posicion($repartidor->latitud_actual, $repartidor->longitud_actual, $repartidor->ubicacion_actualizada_en);
        }

        return null;
    }

    private function posicion(float $latitud, float $longitud, $cuando): array
    {
        return [
            'latitud' => $latitud,
            'longitud' => $longitud,
            'actualizado_en' => $cuando,
            'hace_segundos' => (int) now()->diffInSeconds($cuando, true),
        ];
    }

    /** Distancia en línea recta (km) con la función de la base. */
    private function km(array $desde, array $hasta): float
    {
        return (float) DB::scalar('SELECT fn_distancia_km(?, ?, ?, ?)', [$desde[0], $desde[1], $hasta[0], $hasta[1]]);
    }
}
