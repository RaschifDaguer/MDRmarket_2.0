<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

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
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // La app siempre recibe JSON, aunque olvide mandar "Accept: application/json".
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*'));

        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Tu sesión expiró o no iniciaste sesión.'], 401);
            }
        });

        // Las reglas de negocio de la base (triggers con SIGNAL '45000', ej.
        // "Stock insuficiente") llegan a la app como error 422 con su mensaje.
        $exceptions->render(function (QueryException $e, Request $request) {
            if ($request->is('api/*') && ($e->errorInfo[0] ?? null) === '45000') {
                return response()->json(['message' => $e->errorInfo[2] ?? 'Operación no permitida'], 422);
            }
        });
    })->create();
