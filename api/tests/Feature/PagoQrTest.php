<?php

namespace Tests\Feature;

use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\Usuario;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Pago solo en efectivo o con QR (cobro simulado, ver App\Support\CobroQr). */
class PagoQrTest extends TestCase
{
    use DatabaseTransactions;

    public function test_solo_se_paga_en_efectivo_o_con_qr(): void
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio);
        Sanctum::actingAs($this->crearUsuario());

        foreach (['tarjeta', 'transferencia', 'bitcoin'] as $metodo) {
            $this->postJson('/api/pedidos', $this->datosPedido($negocio, $producto->id, $metodo))
                ->assertUnprocessable()
                ->assertJsonPath('errors.metodo_pago.0', 'Elige pagar en efectivo o con QR.');
        }
        $this->postJson('/api/pedidos', $this->datosPedido($negocio, $producto->id, 'efectivo'))
            ->assertCreated()
            ->assertJsonPath('estado_pago', 'pendiente')
            ->assertJsonMissingPath('pago_qr');
    }

    public function test_pedido_con_qr_simula_el_cobro_y_sigue_el_flujo(): void
    {
        [$cliente, $negocio, $pedido] = $this->pedidoConQr();

        // El negocio no puede aceptarlo mientras el cliente no pague.
        Sanctum::actingAs($negocio->usuario);
        $this->getJson("/api/negocios/{$negocio->id}/pedidos/{$pedido['id']}")
            ->assertOk()
            ->assertJsonPath('acciones', ['rechazado'])
            ->assertJsonMissingPath('pago_qr');
        $this->putJson("/api/negocios/{$negocio->id}/pedidos/{$pedido['id']}/estado", ['estado' => 'confirmado'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.estado.0', 'El cliente todavía no pagó con QR. Podrás aceptarlo cuando pague.');

        // Otro usuario no puede pagarlo (ni saber que existe).
        Sanctum::actingAs($this->crearUsuario());
        $this->postJson("/api/pedidos/{$pedido['id']}/pago-qr")->assertNotFound();

        // "Simular pago" desde la app.
        Sanctum::actingAs($cliente);
        $this->postJson("/api/pedidos/{$pedido['id']}/pago-qr")
            ->assertOk()
            ->assertJsonPath('estado_pago', 'pagado')
            ->assertJsonPath('estado', 'pendiente');
        // Dos veces no cobra doble.
        $this->postJson("/api/pedidos/{$pedido['id']}/pago-qr")->assertOk()->assertJsonPath('estado_pago', 'pagado');
        $this->assertSame(1, Notificacion::where(['usuario_id' => $cliente->id, 'tipo' => 'pago_realizado'])->count());
        $this->assertDatabaseHas('notificacion', ['usuario_id' => $cliente->id, 'titulo' => 'Cobro realizado', 'pedido_id' => $pedido['id']]);
        $this->assertDatabaseHas('notificacion', ['usuario_id' => $negocio->usuario_id, 'tipo' => 'pago_recibido', 'pedido_id' => $pedido['id']]);

        // Pagado: el negocio ya puede aceptarlo y el pedido sigue su curso normal hasta entregarse.
        Sanctum::actingAs($negocio->usuario);
        $this->getJson("/api/negocios/{$negocio->id}/pedidos/{$pedido['id']}")
            ->assertJsonPath('acciones', ['confirmado', 'rechazado']);
        $entregado = $this->entregarPedido(Pedido::find($pedido['id']));
        $this->assertSame('entregado', $entregado->estado);
        $this->assertSame('pagado', $entregado->estado_pago);
    }

    public function test_la_pagina_del_qr_procesa_el_cobro(): void
    {
        [, , $pedido] = $this->pedidoConQr();
        $url = $pedido['pago_qr']['contenido'];
        $this->assertMatchesRegularExpression('#/pago-qr/QR-[A-Za-z0-9]{32}$#', $url);

        // Quien escanea el QR (sin sesión, desde otro celular) ve qué paga.
        $this->app['auth']->forgetGuards();
        $this->get($url)
            ->assertOk()
            ->assertSee('Pago de prueba: no se cobra dinero real.')
            ->assertSee('Bs '.number_format((float) $pedido['total'], 2))
            ->assertSee('Pagar Bs', false);

        $this->post($url)->assertOk()->assertSee('Cobro realizado');
        $this->assertSame('pagado', Pedido::find($pedido['id'])->estado_pago);
        $this->get($url)->assertOk()->assertSee('Cobro realizado');

        // Una referencia inventada no existe.
        $this->get('/pago-qr/QR-'.str_repeat('x', 32))->assertNotFound();
        $this->get('/pago-qr/cualquier-cosa')->assertNotFound();
    }

    public function test_si_se_cancela_un_pedido_pagado_se_devuelve(): void
    {
        [$cliente, , $pedido] = $this->pedidoConQr();
        Sanctum::actingAs($cliente);
        $this->postJson("/api/pedidos/{$pedido['id']}/pago-qr")->assertOk();

        $this->postJson("/api/pedidos/{$pedido['id']}/cancelar")
            ->assertOk()
            ->assertJsonPath('estado', 'cancelado')
            ->assertJsonPath('estado_pago', 'reembolsado');
        $this->assertDatabaseHas('notificacion', ['usuario_id' => $cliente->id, 'tipo' => 'pago_devuelto']);

        // Cancelado y sin pagar: ya no se puede pagar.
        [$otro, , $sinPagar] = $this->pedidoConQr();
        Sanctum::actingAs($otro);
        $this->postJson("/api/pedidos/{$sinPagar['id']}/cancelar")->assertOk();
        $this->postJson("/api/pedidos/{$sinPagar['id']}/pago-qr")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pago.0', 'Este pedido ya fue cancelado: no se puede pagar.');
    }

    public function test_un_pedido_en_efectivo_no_se_paga_con_qr(): void
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio);
        Sanctum::actingAs($this->crearUsuario());
        $id = $this->postJson('/api/pedidos', $this->datosPedido($negocio, $producto->id, 'efectivo'))->json('id');

        $this->postJson("/api/pedidos/$id/pago-qr")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pago.0', 'Este pedido no se paga con QR.');
    }

    /** @return array{0: Usuario, 1: Negocio, 2: array} cliente, negocio y el pedido (JSON) recién hecho con QR. */
    private function pedidoConQr(): array
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio);
        $cliente = $this->crearUsuario();
        Sanctum::actingAs($cliente);

        $pedido = $this->postJson('/api/pedidos', $this->datosPedido($negocio, $producto->id, 'qr'))
            ->assertCreated()
            ->assertJsonPath('metodo_pago', 'qr')
            ->assertJsonPath('estado_pago', 'pendiente')
            ->assertJsonStructure(['pago_qr' => ['referencia', 'contenido']])
            ->json();

        return [$cliente, $negocio, $pedido];
    }

    private function datosPedido(Negocio $negocio, int $productoId, string $metodo): array
    {
        return [
            'negocio_id' => $negocio->id,
            'direccion' => 'Calle Libertad 123',
            'latitud' => -17.7895,
            'longitud' => -63.1803,
            'metodo_pago' => $metodo,
            'items' => [['producto_id' => $productoId, 'cantidad' => 1]],
        ];
    }
}
