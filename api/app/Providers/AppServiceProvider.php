<?php

namespace App\Providers;

use App\Models\Usuario;
use Dedoc\Scramble\Scramble;
use Dedoc\Scramble\Support\Generator\OpenApi;
use Dedoc\Scramble\Support\Generator\SecurityScheme;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Las respuestas van directo, sin envolverlas en {"data": ...}.
        JsonResource::withoutWrapping();

        // Documentación de la API en /docs/api (Scramble): en la PC se ve
        // siempre; en el servidor, solo con sesión de administrador en /admin.
        Gate::define('viewApiDocs', fn (?Usuario $usuario = null) => (bool) $usuario?->es_admin);

        // Botón "Authorize": se pega el token del login (Bearer).
        Scramble::configure()->withDocumentTransformers(function (OpenApi $openApi) {
            $openApi->secure(SecurityScheme::http('bearer'));
        });

        $this->limitesDeSolicitudes();
    }

    /**
     * Cuántas solicitudes puede hacer cada uno por minuto. Frenan a los bots
     * (copiar datos, probar contraseñas, crear pedidos falsos, saturar el
     * servidor). Al pasarse, la API responde 429 "Demasiadas solicitudes".
     * Se cuentan por usuario si tiene sesión, y si no por dirección IP.
     */
    private function limitesDeSolicitudes(): void
    {
        // En las rutas públicas (catálogo) también se mira el token: muchos
        // celulares salen a internet con la misma IP de la operadora.
        $quien = function (Request $request) {
            $usuario = $request->user() ?? $request->user('sanctum');

            return $usuario ? 'u'.$usuario->id : 'ip'.self::ipCliente($request);
        };

        // General, para toda la API. Una persona usando la app hace muchas menos.
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by($quien($request)));

        // Iniciar sesión: por IP y además por correo (frena a quien prueba
        // contraseñas de UNA cuenta desde muchas IP).
        RateLimiter::for('login', fn (Request $request) => [
            Limit::perMinute(10)->by('ip'.self::ipCliente($request)),
            Limit::perMinute(5)->by('correo'.mb_strtolower((string) $request->input('email'))),
        ]);

        // Cuando hay dos límites (por minuto y por día), cada uno lleva su
        // propia clave ("min:" / "dia:"); con la misma, Laravel contaría cada
        // solicitud dos veces.

        // Crear cuentas: pocas por IP (evita cuentas falsas en masa).
        RateLimiter::for('registro', fn (Request $request) => [
            Limit::perMinute(5)->by('min:ip'.self::ipCliente($request)),
            Limit::perDay(30)->by('dia:ip'.self::ipCliente($request)),
        ]);

        // Hacer pedidos: un cliente real no hace más de unos pocos por minuto.
        RateLimiter::for('pedidos', fn (Request $request) => [
            Limit::perMinute(5)->by('min:'.$quien($request)),
            Limit::perDay(50)->by('dia:'.$quien($request)),
        ]);

        // Guardar o cambiar datos (direcciones, productos, estados, reseñas…).
        RateLimiter::for('escritura', fn (Request $request) => Limit::perMinute(40)->by($quien($request)));

        // Subir fotos (negocio, productos, documentos): son lo más pesado.
        RateLimiter::for('subidas', fn (Request $request) => [
            Limit::perMinute(15)->by('min:'.$quien($request)),
            Limit::perDay(200)->by('dia:'.$quien($request)),
        ]);
    }

    /**
     * IP real de quien llama. En Railway la pone el proxy de entrada en
     * X-Real-IP (la que mande el cliente se reemplaza); en la PC no existe y
     * se usa la conexión directa.
     */
    public static function ipCliente(Request $request): string
    {
        $real = $request->header('X-Real-IP');

        return filter_var($real, FILTER_VALIDATE_IP) ? $real : (string) $request->ip();
    }
}
