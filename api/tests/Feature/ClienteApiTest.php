<?php

namespace Tests\Feature;

use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Producto;
use App\Models\Usuario;
use App\Support\FlujoPedido;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Lo que hace el cliente: catálogo, direcciones, envío, pedido, cancelar y reseñar. */
class ClienteApiTest extends TestCase
{
    use DatabaseTransactions;

    /** Dentro del 3er anillo (cerca del negocio de prueba). */
    private const CASA = ['latitud' => -17.7895, 'longitud' => -63.1803];

    public function test_el_catalogo_solo_muestra_negocios_aprobados(): void
    {
        $aprobado = $this->crearNegocio();
        $pendiente = $this->crearNegocio(estado: 'pendiente');
        $visible = $this->crearProducto($aprobado, ['nombre' => 'Salteña zzprueba']);
        $this->crearProducto($pendiente, ['nombre' => 'Salteña zzprueba oculta']);
        $this->crearProducto($aprobado, ['nombre' => 'Salteña zzprueba no disponible', 'disponible' => false]);

        $this->getJson('/api/productos?q=zzprueba')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $visible->id)
            ->assertJsonPath('data.0.negocio.id', $aprobado->id)
            ->assertJsonPath('data.0.categoria_principal.id', 1);

        $this->getJson("/api/tiendas/{$pendiente->id}")->assertNotFound();
        $this->getJson("/api/tiendas/{$aprobado->id}")
            ->assertOk()
            ->assertJsonPath('nombre', 'Negocio de prueba')
            ->assertJsonCount(1, 'productos');
    }

    public function test_la_oferta_vigente_cambia_el_precio_final(): void
    {
        $producto = $this->crearProducto($this->crearNegocio(), [
            'nombre' => 'Torta zzoferta', 'precio' => 50, 'precio_oferta' => 40,
        ]);

        $this->getJson('/api/productos?ofertas=1&q=zzoferta')
            ->assertOk()
            ->assertJsonPath('data.0.precio_final', '40.00')
            ->assertJsonPath('data.0.en_oferta', true)
            ->assertJsonPath('data.0.descuento_pct', 20);

        $this->getJson("/api/productos/{$producto->id}")
            ->assertOk()
            ->assertJsonPath('precio', '50.00')
            ->assertJsonStructure(['imagenes', 'resenas', 'negocio' => ['pedido_minimo']]);
    }

    public function test_direcciones_solo_dentro_de_la_cobertura(): void
    {
        $cliente = $this->crearUsuario();
        Sanctum::actingAs($cliente);

        $casa = $this->postJson('/api/direcciones', ['etiqueta' => 'Casa', 'direccion' => 'Calle 1', ...self::CASA])
            ->assertCreated()
            ->assertJsonPath('predeterminada', true); // la primera queda como predeterminada

        $trabajo = $this->postJson('/api/direcciones', [
            'etiqueta' => 'Trabajo', 'direccion' => 'Calle 2', 'latitud' => -17.78, 'longitud' => -63.18, 'predeterminada' => true,
        ])->assertCreated();

        $this->postJson('/api/direcciones', ['direccion' => 'La Paz', 'latitud' => -16.5, 'longitud' => -68.15])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('latitud');

        $this->getJson('/api/direcciones')
            ->assertOk()
            ->assertJsonCount(2)
            ->assertJsonPath('0.id', $trabajo->json('id')) // la predeterminada primero
            ->assertJsonPath('1.predeterminada', false);

        // Una dirección ajena no existe para este usuario.
        Sanctum::actingAs($this->crearUsuario());
        $this->deleteJson('/api/direcciones/'.$casa->json('id'))->assertNotFound();
    }

    public function test_cotizar_el_envio(): void
    {
        $negocio = $this->crearNegocio();
        Sanctum::actingAs($this->crearUsuario());

        $this->postJson('/api/envio/cotizar', ['negocio_id' => $negocio->id, ...self::CASA])
            ->assertOk()
            ->assertJsonStructure(['costo_envio', 'distancia_km', 'anillo', 'tarifa_servicio']);

        $this->postJson('/api/envio/cotizar', ['negocio_id' => $negocio->id, 'latitud' => -16.5, 'longitud' => -68.15])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('latitud');
    }

    public function test_hacer_un_pedido(): void
    {
        $negocio = $this->crearNegocio();
        $pan = $this->crearProducto($negocio, ['nombre' => 'Pan', 'precio' => 10, 'stock' => 20]);
        $torta = $this->crearProducto($negocio, ['nombre' => 'Torta', 'precio' => 50, 'precio_oferta' => 40, 'stock' => null]);
        $cliente = $this->crearUsuario();

        $respuesta = $this->pedir($cliente, $negocio, [[$pan, 3], [$torta, 1]])->assertCreated();

        $respuesta
            ->assertJsonPath('estado', 'pendiente')
            ->assertJsonPath('subtotal', '70.00') // 3 × 10 + 1 × 40 (con oferta)
            ->assertJsonPath('items.1.precio_unitario', '40.00')
            ->assertJsonPath('acciones', ['cancelado']);
        $this->assertMatchesRegularExpression('/^\d{4}$/', $respuesta->json('codigo_entrega'));
        $this->assertEquals(
            (float) $respuesta->json('subtotal') + (float) $respuesta->json('costo_envio') + (float) $respuesta->json('tarifa_servicio'),
            (float) $respuesta->json('total')
        );

        $this->assertSame(17, $pan->refresh()->stock); // la base descontó el stock
        $this->assertTrue(Notificacion::where('usuario_id', $negocio->usuario_id)->where('tipo', 'pedido_nuevo')->exists());

        // Mis pedidos.
        $this->getJson('/api/pedidos')->assertOk()->assertJsonPath('data.0.id', $respuesta->json('id'));

        // El negocio ve el pedido, pero no el PIN.
        Sanctum::actingAs($negocio->usuario);
        $this->getJson('/api/pedidos/'.$respuesta->json('id'))
            ->assertOk()
            ->assertJsonMissingPath('codigo_entrega')
            ->assertJsonPath('cliente.nombre', 'Prueba Usuario');

        // Otra persona no lo ve.
        Sanctum::actingAs($this->crearUsuario());
        $this->getJson('/api/pedidos/'.$respuesta->json('id'))->assertNotFound();
    }

    public function test_reglas_del_pedido(): void
    {
        $negocio = $this->crearNegocio(datos: ['pedido_minimo' => 15]);
        $producto = $this->crearProducto($negocio, ['precio' => 10, 'stock' => 2]);
        $otro = $this->crearProducto($this->crearNegocio(), ['precio' => 10]);
        $cliente = $this->crearUsuario();

        $this->pedir($cliente, $negocio, [[$producto, 5]])
            ->assertUnprocessable()->assertJsonPath('errors', ['items.0.cantidad' => ['Solo quedan 2 de «Producto de prueba».']]);
        $this->pedir($cliente, $negocio, [[$producto, 1]])
            ->assertUnprocessable()->assertJsonValidationErrors('items'); // Bs 10 no llega al mínimo de Bs 15
        $this->pedir($cliente, $negocio, [[$otro, 1]])
            ->assertUnprocessable()->assertJsonValidationErrors('items.0.producto_id');
        $this->pedir($negocio->usuario, $negocio, [[$producto, 2]])
            ->assertUnprocessable()->assertJsonPath('errors.negocio_id.0', 'No puedes hacer pedidos a tu propio negocio.');
        $this->pedir($cliente, $negocio, [[$producto, 2]], ['latitud' => -16.5, 'longitud' => -68.15])
            ->assertUnprocessable()->assertJsonValidationErrors('latitud');

        $negocio->update(['abierto' => false]);
        $this->pedir($cliente, $negocio, [[$producto, 2]])
            ->assertUnprocessable()->assertJsonPath('errors.negocio_id.0', 'El negocio está cerrado en este momento.');

        $this->assertSame(2, $producto->refresh()->stock); // nada se descontó
    }

    public function test_cancelar_solo_antes_de_que_lo_acepten(): void
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio, ['stock' => 10]);
        $cliente = $this->crearUsuario();

        $id = $this->pedir($cliente, $negocio, [[$producto, 4]])->json('id');
        $this->postJson("/api/pedidos/$id/cancelar", ['motivo' => 'Me equivoqué'])
            ->assertOk()->assertJsonPath('estado', 'cancelado');
        $this->assertSame(10, $producto->refresh()->stock); // volvió el stock

        $otro = $this->pedir($cliente, $negocio, [[$producto, 1]])->json('id');
        FlujoPedido::cambiar($negocio->pedidos()->find($otro), 'confirmado', $negocio->usuario, 'comerciante');
        $this->postJson("/api/pedidos/$otro/cancelar")
            ->assertUnprocessable()->assertJsonValidationErrors('estado');
    }

    public function test_resenar_despues_de_recibir(): void
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio);
        $cliente = $this->crearUsuario();
        $id = $this->pedir($cliente, $negocio, [[$producto, 1]])->json('id');

        $resena = ['tipo' => 'negocio', 'negocio_id' => $negocio->id, 'estrellas' => 4, 'comentario' => 'Muy rico'];
        $this->putJson('/api/resenas', $resena)
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Solo puedes reseñar después de recibir un pedido');

        $this->entregar($negocio, $id);

        $this->putJson('/api/resenas', $resena)->assertCreated()->assertJsonPath('estrellas', 4)->assertJsonPath('autor', 'Prueba U.');
        $this->putJson('/api/resenas', [...$resena, 'estrellas' => 2])->assertOk(); // edita la misma
        $this->putJson('/api/resenas', ['tipo' => 'producto', 'producto_id' => $producto->id, 'estrellas' => 5])->assertCreated();

        $this->assertSame(1, $negocio->refresh()->total_resenas);
        $this->assertEquals(2.0, $negocio->rating_promedio);
        $this->getJson("/api/pedidos/$id")
            ->assertJsonPath('mis_resenas.negocio.estrellas', 2)
            ->assertJsonPath("mis_resenas.productos.0.producto_id", $producto->id)
            ->assertJsonPath("mis_resenas.productos.0.estrellas", 5);
    }

    /** @param array<array{0: Producto, 1: int}> $items */
    private function pedir(Usuario $cliente, Negocio $negocio, array $items, array $extra = []): TestResponse
    {
        Sanctum::actingAs($cliente);

        return $this->postJson('/api/pedidos', [
            'negocio_id' => $negocio->id,
            'direccion' => 'Calle Libertad 123',
            ...self::CASA,
            'metodo_pago' => 'efectivo',
            'items' => array_map(fn ($i) => ['producto_id' => $i[0]->id, 'cantidad' => $i[1]], $items),
            ...$extra,
        ]);
    }

    /** El negocio lleva el pedido hasta "entregado" (sin pasar por la API). */
    private function entregar(Negocio $negocio, int $pedidoId): void
    {
        $pedido = $negocio->pedidos()->find($pedidoId);
        foreach (['confirmado', 'preparando', 'listo', 'en_camino', 'entregado'] as $estado) {
            $pedido = FlujoPedido::cambiar($pedido, $estado, $negocio->usuario, 'comerciante');
        }
    }
}
