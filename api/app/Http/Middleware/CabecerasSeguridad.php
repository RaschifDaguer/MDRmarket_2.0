<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Cabeceras de seguridad en todas las respuestas (API, panel y documentación).
 * Le indican al navegador qué NO permitir:
 * - nosniff: no "adivinar" el tipo de un archivo (una foto no se ejecuta como script);
 * - DENY: ningún otro sitio puede mostrar el panel dentro de un marco (clickjacking);
 * - HSTS: usar siempre HTTPS con este dominio;
 * - en /api, una política que no deja ejecutar nada (la API solo devuelve datos y fotos).
 */
class CabecerasSeguridad
{
    public function handle(Request $request, Closure $next): Response
    {
        $respuesta = $next($request);
        $cabeceras = $respuesta->headers;

        $cabeceras->set('X-Content-Type-Options', 'nosniff');
        $cabeceras->set('X-Frame-Options', 'DENY');
        $cabeceras->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $cabeceras->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
        $cabeceras->set('Cross-Origin-Opener-Policy', 'same-origin');

        if ($request->isSecure()) {
            $cabeceras->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        }

        if ($request->is('api/*')) {
            $cabeceras->set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
        }

        // No revelar la versión de PHP.
        $cabeceras->remove('X-Powered-By');
        header_remove('X-Powered-By');

        return $respuesta;
    }
}
