<?php

use App\Models\Usuario;
use Illuminate\Support\Facades\Artisan;

// Da permiso de administrador (panel /admin) a una cuenta ya registrada en la app.
//   php artisan mdr:admin correo@ejemplo.com
//   php artisan mdr:admin correo@ejemplo.com --quitar
Artisan::command('mdr:admin {email} {--quitar : Quita el permiso en vez de darlo}', function (string $email) {
    $usuario = Usuario::where('email', $email)->first();
    if (! $usuario) {
        $this->error("No existe una cuenta con el correo {$email}. Regístrala primero desde la app.");

        return 1;
    }

    $usuario->forceFill(['es_admin' => ! $this->option('quitar')])->save();
    $this->info($usuario->es_admin
        ? "{$usuario->nombre_completo} ya es administrador. Entra en /admin con su correo y contraseña."
        : "{$usuario->nombre_completo} ya no es administrador.");

    return 0;
})->purpose('Dar o quitar permiso de administrador a una cuenta');
