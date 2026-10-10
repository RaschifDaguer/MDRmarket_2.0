<?php

namespace App\Http\Middleware;

use App\Models\Negocio;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Rutas /api/negocios/{negocio}/…: solo el dueño del negocio puede usarlas.
 * A cualquier otro le responde 404 (no se revela que el negocio existe).
 */
class DuenoDelNegocio
{
    public function handle(Request $request, Closure $next): Response
    {
        $negocio = $request->route('negocio');
        abort_unless(
            $negocio instanceof Negocio && (int) $negocio->usuario_id === (int) $request->user()?->id,
            404
        );

        return $next($request);
    }
}
