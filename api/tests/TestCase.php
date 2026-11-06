<?php

namespace Tests;

use App\Models\Negocio;
use App\Models\Pedido;
use App\Models\Producto;
use App\Models\Repartidor;
use App\Models\Usuario;
use App\Support\FlujoPedido;
use Filament\Auth\MultiFactor\App\AppAuthentication;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Str;

/**
 * Las pruebas corren sobre la base `mdrmarket_prueba` (creada con el script
 * maestro). Las que guardan datos usan DatabaseTransactions: al terminar cada
 * prueba se deshace todo.
 */
abstract class TestCase extends BaseTestCase
{
    protected function crearUsuario(array $datos = [], bool $admin = false): Usuario
    {
        $usuario = Usuario::create([
            'nombre' => 'Prueba',
            'apellido' => 'Usuario',
            'email' => 'prueba.'.Str::random(10).'@mdrmarket.local',
            'password' => 'Secreta123',
            'ci_numero' => (string) random_int(10000000, 99999999),
            ...$datos,
        ]);
        if ($admin) {
            // Admin que ya configuró la verificación en dos pasos (obligatoria en /admin).
            $usuario->forceFill([
                'es_admin' => true,
                'app_authentication_secret' => app(AppAuthentication::class)->generateSecret(),
            ])->save();
        }

        return $usuario->refresh();
    }

    /** Negocio en el centro de Santa Cruz (dentro de la cobertura). */
    protected function crearNegocio(?Usuario $dueno = null, string $estado = 'aprobado', array $datos = []): Negocio
    {
        $dueno ??= $this->crearUsuario();
        $negocio = $dueno->negocios()->create([
            'categoria_id' => 1,
            'nombre' => 'Negocio de prueba',
            'direccion' => 'Av. Busch 1234',
            'latitud' => -17.7745,
            'longitud' => -63.1935,
            'logo_url' => 'negocios/prueba.png',
            ...$datos,
        ]);
        $negocio->forceFill(['estado_verificacion' => $estado])->save();

        return $negocio->refresh();
    }

    /** Pedido de un producto, directo en la base (sin pasar por la API). */
    protected function crearPedido(Negocio $negocio, Producto $producto, int $cantidad = 1, ?Usuario $comprador = null): Pedido
    {
        $comprador ??= $this->crearUsuario();
        $pedido = Pedido::create([
            'comprador_id' => $comprador->id,
            'negocio_id' => $negocio->id,
            'direccion_entrega' => 'Calle Libertad 123',
            'latitud_entrega' => -17.79,
            'longitud_entrega' => -63.18,
            'subtotal' => $producto->precio * $cantidad,
            'costo_envio' => 5,
            'codigo_entrega' => '1234',
        ]);
        // La base descuenta el stock al insertar el ítem.
        $pedido->items()->create([
            'producto_id' => $producto->id,
            'producto_nombre' => $producto->nombre,
            'precio_unitario' => $producto->precio,
            'cantidad' => $cantidad,
        ]);

        return $pedido->refresh();
    }

    /**
     * Repartidor con su vehículo (moto, aprobado y en línea, salvo que se pida
     * otra cosa). Devuelve su usuario.
     */
    protected function crearRepartidor(int $tipo = 1, string $placa = '7777-MDR', string $estado = 'aprobado', bool $disponible = true): Usuario
    {
        $usuario = $this->crearUsuario(['nombre' => 'Diego', 'apellido' => 'Repartidor']);
        $repartidor = Repartidor::create(['usuario_id' => $usuario->id]);
        $repartidor->forceFill(['estado_verificacion' => $estado, 'disponible' => $disponible])->save();
        $vehiculo = $repartidor->vehiculos()->create(['tipo_vehiculo_id' => $tipo, 'placa' => $placa, 'ruat' => 'R-1']);
        $vehiculo->forceFill(['estado_verificacion' => $estado === 'aprobado' ? 'aprobado' : 'pendiente'])->save();

        return $usuario;
    }

    /**
     * Lleva un pedido hasta "entregado" como en la vida real (sin pasar por la
     * API): el negocio lo deja listo y un repartidor lo acepta, lo recoge y lo entrega.
     */
    protected function entregarPedido(Pedido $pedido, ?Usuario $repartidor = null): Pedido
    {
        $negocio = $pedido->negocio;
        foreach (['confirmado', 'preparando', 'listo'] as $estado) {
            $pedido = FlujoPedido::cambiar($pedido, $estado, $negocio->usuario, 'comerciante');
        }
        $repartidor ??= $this->crearRepartidor(placa: 'E-'.$pedido->id);
        $perfil = Repartidor::find($repartidor->id);
        $pedido = FlujoPedido::aceptar($pedido, $perfil, $perfil->vehiculoAprobado());
        foreach (['en_camino', 'entregado'] as $estado) {
            $pedido = FlujoPedido::cambiar($pedido, $estado, $repartidor, 'repartidor');
        }

        return $pedido;
    }

    /** Producto en una subcategoría de Alimentos (101). */
    protected function crearProducto(Negocio $negocio, array $datos = []): Producto
    {
        return $negocio->productos()->create([
            'categoria_id' => 101,
            'nombre' => 'Producto de prueba',
            'precio' => 20,
            'costo' => 12,
            'stock' => 10,
            ...$datos,
        ])->refresh();
    }
}
