<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\LostConnectionDetector;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Foundation\Exceptions\RegisterErrorViewPaths;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        // Railway pone un proxy HTTPS delante: así las URLs (ej. de las fotos)
        // salen con https y no con http.
        $middleware->trustProxies(at: '*');

        $middleware->alias([
            'dueno.negocio' => \App\Http\Middleware\DuenoDelNegocio::class,
        ]);

        // Cabeceras de seguridad en todas las respuestas.
        $middleware->append(\App\Http\Middleware\CabecerasSeguridad::class);

        // Límite general de solicitudes por minuto en toda la API (ver AppServiceProvider).
        $middleware->throttleApi('api');
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // La app siempre recibe JSON, aunque olvide mandar "Accept: application/json".
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*'));

        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Tu sesión expiró o no iniciaste sesión.'], 401);
            }
        });

        // Se pasó del límite de solicitudes: mensaje claro y cuántos segundos esperar.
        $exceptions->render(function (ThrottleRequestsException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(
                    ['message' => 'Demasiadas solicitudes seguidas. Espera un momento y vuelve a intentar.'],
                    429,
                    $e->getHeaders(),
                );
            }
        });

        // La base de datos está apagada o no responde (ej. el plan gratis de
        // Aiven se duerme): 503 "en mantenimiento" en vez de "Error del servidor".
        $exceptions->render(function (Throwable $e, Request $request) {
            $sinBase = ($e instanceof QueryException || $e instanceof PDOException)
                && (app(LostConnectionDetector::class)->causedByLostConnection($e)
                    || Str::contains($e->getMessage(), ['[2002]', '[2006]']));
            if (! $sinBase) {
                return null;
            }
            if ($request->is('api/*')) {
                return response()->json(['message' => 'El servicio está en mantenimiento. Vuelve a intentar en unos minutos.'], 503);
            }
            (new RegisterErrorViewPaths)(); // la página usa la plantilla de errores de Laravel

            return response()->view('errors.503', [], 503);
        });

        // Las reglas de negocio de la base (triggers con SIGNAL '45000', ej.
        // "Stock insuficiente") llegan a la app como error 422 con su mensaje.
        $exceptions->render(function (QueryException $e, Request $request) {
            if ($request->is('api/*') && ($e->errorInfo[0] ?? null) === '45000') {
                return response()->json(['message' => $e->errorInfo[2] ?? 'Operación no permitida'], 422);
            }
        });
    })->create();
