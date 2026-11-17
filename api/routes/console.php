<?php

use App\Models\Usuario;
use App\Support\VencimientoPedidos;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

// Pedidos que nadie atendió a tiempo: rechaza los nuevos que la tienda no
// respondió, cancela los QR que no se pagaron y los listos que ningún
// repartidor tomó (ver VencimientoPedidos). Lo corre solo el programador
// (abajo); también a mano:
//   php artisan pedidos:vencer
Artisan::command('pedidos:vencer', function () {
    $hechos = VencimientoPedidos::ejecutar();
    if (array_sum($hechos) > 0) {
        $this->info("Rechazados sin respuesta: {$hechos['rechazados']}. Cancelados sin pago QR: {$hechos['sin_pago']}. "
            ."Cancelados sin repartidor: {$hechos['cancelados']}.");
    }

    return 0;
})->purpose('Rechaza o cancela los pedidos que nadie atendió a tiempo');

// Tareas automáticas. Las corre `php artisan schedule:work`, que el contenedor
// de la API arranca solo (docker/entrypoint.sh, variable TAREAS_AUTOMATICAS).
// Cada 15 segundos: con un plazo de 1 minuto, el pedido se rechaza entre los
// 60 y los 75 segundos. Sin superponerse si una pasada tarda.
Schedule::command('pedidos:vencer')->everyFifteenSeconds()->withoutOverlapping(5);

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
