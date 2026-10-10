<?php

namespace App\Providers;

use App\Models\Usuario;
use Dedoc\Scramble\Scramble;
use Dedoc\Scramble\Support\Generator\OpenApi;
use Dedoc\Scramble\Support\Generator\SecurityScheme;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Gate;
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

        // Documentación de la API en /docs/api (Scramble). Se ve también en
        // Railway, para el equipo que trabaja sin la API local (el repo ya es público).
        Gate::define('viewApiDocs', fn (?Usuario $usuario = null) => true);

        // Botón "Authorize": se pega el token del login (Bearer).
        Scramble::configure()->withDocumentTransformers(function (OpenApi $openApi) {
            $openApi->secure(SecurityScheme::http('bearer'));
        });
    }
}
