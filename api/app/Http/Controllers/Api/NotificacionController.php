<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notificacion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Avisos del usuario (pedido nuevo, pedido en camino, negocio aprobado…). Solo los suyos. */
class NotificacionController extends Controller
{
    /** GET /api/notificaciones?no_leidas=1 — de la más nueva a la más vieja, con cuántas faltan leer. */
    public function index(Request $request): JsonResponse
    {
        $soloNoLeidas = $request->validate(['no_leidas' => ['nullable', 'boolean']])['no_leidas'] ?? false;
        $propias = Notificacion::where('usuario_id', $request->user()->id);

        $pagina = (clone $propias)
            ->when($soloNoLeidas, fn ($q) => $q->whereNull('leida_en'))
            ->latest('id')
            ->paginate(30)
            ->withQueryString();

        return response()->json([
            'data' => $pagina->getCollection()->map(fn (Notificacion $n) => $this->formato($n)),
            'meta' => [
                'pagina' => $pagina->currentPage(),
                'ultima_pagina' => $pagina->lastPage(),
                'total' => $pagina->total(),
                'no_leidas' => (clone $propias)->whereNull('leida_en')->count(),
            ],
        ]);
    }

    /** POST /api/notificaciones/{id}/leida — marca una como leída (404 si no es suya). */
    public function leida(Request $request, int $id): JsonResponse
    {
        $notificacion = Notificacion::where('usuario_id', $request->user()->id)->findOrFail($id);
        if ($notificacion->leida_en === null) {
            $notificacion->forceFill(['leida_en' => now()])->save();
        }

        return response()->json($this->formato($notificacion));
    }

    /** POST /api/notificaciones/leidas — marca todas como leídas. */
    public function todasLeidas(Request $request): JsonResponse
    {
        $marcadas = Notificacion::where('usuario_id', $request->user()->id)
            ->whereNull('leida_en')
            ->update(['leida_en' => now()]);

        return response()->json(['marcadas' => $marcadas, 'no_leidas' => 0]);
    }

    private function formato(Notificacion $n): array
    {
        return [
            'id' => $n->id,
            'tipo' => $n->tipo,
            'titulo' => $n->titulo,
            'cuerpo' => $n->cuerpo,
            'pedido_id' => $n->pedido_id,
            'leida' => $n->leida_en !== null,
            'leida_en' => $n->leida_en,
            'created_at' => $n->created_at,
        ];
    }
}
