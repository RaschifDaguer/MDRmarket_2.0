<?php

namespace Tests\Feature;

use App\Filament\Resources\Pedidos\Pages\ListPedidos;
use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\Producto;
use App\Models\RegistroComercio;
use App\Models\Repartidor;
use App\Models\Usuario;
use App\Support\CobroQr;
use App\Support\FlujoPedido;
use App\Support\VencimientoPedidos;
use Filament\Actions\Testing\TestAction;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Sanctum;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Regla de pedidos (fase 0):
 * - la tienda solo acepta o rechaza un pedido nuevo; aceptado, ya no lo cancela;
 * - si no responde a tiempo, el pedido se rechaza solo;
 * - si ningún repartidor toma un pedido listo a tiempo, se cancela solo;
 * - el admin puede cancelarlo a mano;
 * - la entrega siempre la hace un repartidor de la app.
 */
class ReglaPedidosTest extends TestCase
{
    use DatabaseTransactions;

    private Negocio $negocio;

    private Producto $producto;

    protected function setUp(): void
    {
        parent::setUp();
        $this->negocio = $this->crearNegocio();
        $this->producto = $this->crearProducto($this->negocio, ['stock' => 10]);
        // Plazos de la regla (los de la base de producción).
        $this->plazo('minutos_para_aceptar', 1);
        $this->plazo('minutos_listo_sin_repartidor', 30);
        $this->plazo('minutos_para_pagar_qr', 10);
    }

    // ---------- La tienda: aceptar o rechazar, y después ya no cancelar ----------

    public function test_la_tienda_solo_acepta_o_rechaza_y_aceptado_ya_no_cancela(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto);
        Sanctum::actingAs($this->negocio->usuario);
        $url = "/api/negocios/{$this->negocio->id}/pedidos/{$pedido->id}";

        // Nuevo: solo Aceptar o Rechazar (cancelar no es para la tienda).
        $this->getJson($url)->assertJsonPath('acciones', ['confirmado', 'rechazado']);
        $this->putJson("$url/estado", ['estado' => 'cancelado', 'motivo' => 'x'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.estado.0', 'Para no atender un pedido nuevo, recházalo y dile al cliente por qué.');

        // Aceptado: solo avanzar. En ningún paso puede cancelarlo.
        $siguiente = ['confirmado' => ['preparando'], 'preparando' => ['listo'], 'listo' => []];
        foreach ($siguiente as $estado => $acciones) {
            $this->putJson("$url/estado", ['estado' => $estado])->assertOk();
            $this->getJson($url)->assertJsonPath('acciones', $acciones);
            $this->putJson("$url/estado", ['estado' => 'cancelado', 'motivo' => 'Sin stock'])
                ->assertUnprocessable()
                ->assertJsonPath('errors.estado.0', 'Un pedido aceptado ya no se puede cancelar. Si tienes un problema, avisa a MDR Market.');
            $this->assertSame($estado, $pedido->refresh()->estado);
        }
        // El stock sigue reservado para el cliente.
        $this->assertSame(9, $this->producto->refresh()->stock);
    }

    public function test_rechazar_por_falta_de_stock_devuelve_el_stock_y_el_cliente_ve_el_motivo(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto, 3);
        $this->assertSame(7, $this->producto->refresh()->stock);

        Sanctum::actingAs($this->negocio->usuario);
        $this->putJson("/api/negocios/{$this->negocio->id}/pedidos/{$pedido->id}/estado", ['estado' => 'rechazado', 'motivo' => 'Sin stock'])
            ->assertOk()
            ->assertJsonPath('estado', 'rechazado');

        $this->assertSame(10, $this->producto->refresh()->stock);
        Sanctum::actingAs($pedido->comprador);
        $this->getJson("/api/pedidos/{$pedido->id}")->assertJsonPath('motivo_cancelacion', 'Sin stock');
    }

    public function test_el_cliente_no_puede_pedir_mas_que_el_stock(): void
    {
        $producto = $this->crearProducto($this->negocio, ['stock' => 2]);
        Sanctum::actingAs($this->crearUsuario());

        $this->postJson('/api/pedidos', [
            'negocio_id' => $this->negocio->id,
            'direccion' => 'Calle Libertad 123',
            'latitud' => -17.79,
            'longitud' => -63.18,
            'metodo_pago' => 'efectivo',
            'items' => [['producto_id' => $producto->id, 'cantidad' => 3]],
        ])->assertUnprocessable()->assertJsonValidationErrors(['items.0.cantidad' => 'Solo quedan 2 de «Producto de prueba».']);

        $this->assertSame(2, $producto->refresh()->stock);
    }

    // ---------- La tienda no responde: se rechaza solo ----------

    public function test_pedido_nuevo_sin_respuesta_se_rechaza_solo_al_pasar_el_plazo(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto, 2);
        $this->assertSame(8, $this->producto->refresh()->stock);

        // Antes del minuto, no pasa nada.
        $this->travel(50)->seconds();
        $this->vencer();
        $this->assertSame('pendiente', $pedido->refresh()->estado);

        $this->travel(15)->seconds();
        $this->vencer();
        $pedido->refresh();
        $this->assertSame('rechazado', $pedido->estado);
        $this->assertSame(VencimientoPedidos::MOTIVO_SIN_RESPUESTA, $pedido->motivo_cancelacion);
        $this->assertNull($pedido->cancelado_por);
        $this->assertNotNull($pedido->cancelado_en);
        // La base devolvió el stock.
        $this->assertSame(10, $this->producto->refresh()->stock);

        // Historial: lo hizo el sistema, con el motivo.
        $ultimo = $pedido->historial()->get()->last();
        $this->assertSame('sistema', $ultimo->rol);
        $this->assertSame('rechazado', $ultimo->estado_nuevo);
        $this->assertNull($ultimo->usuario_id);

        // Se enteran el cliente (con el motivo) y la tienda.
        $this->assertTrue(Notificacion::where('usuario_id', $pedido->comprador_id)->where('pedido_id', $pedido->id)
            ->where('tipo', 'pedido_rechazado')->where('cuerpo', 'La tienda no respondió a tiempo')->exists());
        $this->assertTrue(Notificacion::where('usuario_id', $this->negocio->usuario_id)->where('pedido_id', $pedido->id)
            ->where('titulo', "El pedido #{$pedido->id} se rechazó solo")->exists());

        // Pasar otra vez no cambia nada (no se rechaza dos veces).
        $this->assertSame(['rechazados' => 0, 'sin_pago' => 0, 'cancelados' => 0], VencimientoPedidos::ejecutar());
    }

    public function test_si_la_tienda_acepta_a_tiempo_no_se_rechaza(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto);
        $this->travel(40)->seconds();
        FlujoPedido::cambiar($pedido, 'confirmado', $this->negocio->usuario, 'comerciante');

        $this->travel(10)->minutes();
        $this->vencer();
        $this->assertSame('confirmado', $pedido->refresh()->estado);
    }

    public function test_el_plazo_para_aceptar_se_cambia_en_configuracion(): void
    {
        $this->plazo('minutos_para_aceptar', 5);
        $pedido = $this->crearPedido($this->negocio, $this->producto);

        $this->travel(4)->minutes();
        $this->vencer();
        $this->assertSame('pendiente', $pedido->refresh()->estado);

        $this->travel(61)->seconds();
        $this->vencer();
        $this->assertSame('rechazado', $pedido->refresh()->estado);
    }

    public function test_sin_configuracion_usa_un_minuto(): void
    {
        DB::table('configuracion')->where('clave', 'minutos_para_aceptar')->delete();
        $pedido = $this->crearPedido($this->negocio, $this->producto);

        $this->travel(61)->seconds();
        $this->vencer();
        $this->assertSame('rechazado', $pedido->refresh()->estado);
    }

    public function test_con_qr_el_plazo_corre_desde_que_el_cliente_paga_y_se_reembolsa(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto);
        $pedido->forceFill(['metodo_pago' => 'qr', 'referencia_pago' => CobroQr::nuevaReferencia()])->save();

        // Sin pagar, la tienda no puede aceptarlo: su plazo todavía no corre
        // (y el cliente tiene 10 minutos para pagar).
        $this->travel(5)->minutes();
        $this->vencer();
        $this->assertSame('pendiente', $pedido->refresh()->estado);

        CobroQr::procesar($pedido);
        $this->travel(30)->seconds();
        $this->vencer();
        $this->assertSame('pendiente', $pedido->refresh()->estado);

        $this->travel(31)->seconds();
        $this->vencer();
        $pedido->refresh();
        $this->assertSame('rechazado', $pedido->estado);
        $this->assertSame('reembolsado', $pedido->estado_pago);
        $this->assertTrue(Notificacion::where('usuario_id', $pedido->comprador_id)->where('tipo', 'pago_devuelto')->exists());
    }

    // ---------- El cliente no paga el QR: se cancela solo ----------

    public function test_qr_sin_pagar_se_cancela_solo_a_los_10_minutos_y_libera_el_stock(): void
    {
        $pedido = $this->pedidoQr(cantidad: 3);
        $this->assertSame(7, $this->producto->refresh()->stock);

        $this->travel(9)->minutes();
        $this->vencer();
        $this->assertSame('pendiente', $pedido->refresh()->estado);

        $this->travel(61)->seconds();
        $this->vencer();
        $pedido->refresh();
        $this->assertSame('cancelado', $pedido->estado);
        $this->assertSame(VencimientoPedidos::MOTIVO_SIN_PAGO, $pedido->motivo_cancelacion);
        // No se cobró nada: no hay nada que reembolsar.
        $this->assertSame('pendiente', $pedido->estado_pago);
        $this->assertSame('sistema', $pedido->historial()->get()->last()->rol);
        $this->assertSame(10, $this->producto->refresh()->stock);

        // Se enteran el cliente (con el motivo) y la tienda.
        $this->assertTrue(Notificacion::where('usuario_id', $pedido->comprador_id)->where('pedido_id', $pedido->id)
            ->where('tipo', 'pedido_cancelado')->where('cuerpo', VencimientoPedidos::MOTIVO_SIN_PAGO)->exists());
        $this->assertTrue(Notificacion::where('usuario_id', $this->negocio->usuario_id)->where('pedido_id', $pedido->id)
            ->where('titulo', "El pedido #{$pedido->id} se canceló solo")->where('cuerpo', VencimientoPedidos::MOTIVO_SIN_PAGO)->exists());
        $this->assertFalse(Notificacion::where('pedido_id', $pedido->id)->where('tipo', 'pago_devuelto')->exists());

        // Ya cancelado, no se puede pagar.
        Sanctum::actingAs($pedido->comprador);
        $this->postJson("/api/pedidos/{$pedido->id}/pago-qr")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pago.0', 'Este pedido ya fue cancelado: no se puede pagar.');
    }

    public function test_si_paga_a_tiempo_no_se_cancela_por_falta_de_pago(): void
    {
        $pedido = $this->pedidoQr();
        $this->travel(9)->minutes();
        CobroQr::procesar($pedido);
        // La tienda lo acepta enseguida.
        FlujoPedido::cambiar($pedido, 'confirmado', $this->negocio->usuario, 'comerciante');

        $this->travel(30)->minutes();
        $this->vencer();
        $pedido->refresh();
        $this->assertSame('confirmado', $pedido->estado);
        $this->assertSame('pagado', $pedido->estado_pago);
    }

    public function test_el_sistema_no_cancela_por_falta_de_pago_un_pedido_ya_pagado(): void
    {
        // Pagó justo antes de que la tarea lo tocara: no se cancela.
        $pedido = $this->pedidoQr();
        CobroQr::procesar($pedido);

        $this->expectException(ValidationException::class);
        FlujoPedido::cambiar($pedido, 'cancelado', null, 'sistema', VencimientoPedidos::MOTIVO_SIN_PAGO);
    }

    public function test_el_plazo_para_pagar_se_cambia_en_configuracion(): void
    {
        $this->plazo('minutos_para_pagar_qr', 3);
        $pedido = $this->pedidoQr();

        $this->travel(2)->minutes();
        $this->vencer();
        $this->assertSame('pendiente', $pedido->refresh()->estado);

        $this->travel(61)->seconds();
        $this->vencer();
        $this->assertSame('cancelado', $pedido->refresh()->estado);
    }

    public function test_efectivo_no_se_cancela_por_falta_de_pago(): void
    {
        // En efectivo se paga al recibir: lo que vence es la respuesta de la tienda.
        $pedido = $this->crearPedido($this->negocio, $this->producto);
        $this->travel(15)->minutes();
        $this->vencer();
        $pedido->refresh();
        $this->assertSame('rechazado', $pedido->estado);
        $this->assertSame(VencimientoPedidos::MOTIVO_SIN_RESPUESTA, $pedido->motivo_cancelacion);
    }

    // ---------- Ningún repartidor lo toma: se cancela solo ----------

    public function test_pedido_listo_sin_repartidor_se_cancela_solo_a_los_30_minutos(): void
    {
        $pedido = $this->pedidoListo(cantidad: 2);
        $this->assertSame(8, $this->producto->refresh()->stock);

        $this->travel(29)->minutes();
        $this->vencer();
        $this->assertSame('listo', $pedido->refresh()->estado);

        $this->travel(61)->seconds();
        $this->vencer();
        $pedido->refresh();
        $this->assertSame('cancelado', $pedido->estado);
        $this->assertSame(VencimientoPedidos::MOTIVO_SIN_REPARTIDOR, $pedido->motivo_cancelacion);
        $this->assertSame('sistema', $pedido->historial()->get()->last()->rol);
        $this->assertSame(10, $this->producto->refresh()->stock);
        $this->assertTrue(Notificacion::where('usuario_id', $pedido->comprador_id)->where('tipo', 'pedido_cancelado')
            ->where('cuerpo', VencimientoPedidos::MOTIVO_SIN_REPARTIDOR)->exists());
        $this->assertTrue(Notificacion::where('usuario_id', $this->negocio->usuario_id)
            ->where('titulo', "El pedido #{$pedido->id} se canceló solo")->exists());
    }

    public function test_si_un_repartidor_lo_toma_no_se_cancela(): void
    {
        $pedido = $this->pedidoListo();
        $this->travel(20)->minutes();
        $this->aceptar($pedido);

        $this->travel(2)->hours();
        $this->vencer();
        $this->assertSame('listo', $pedido->refresh()->estado);
        $this->assertNotNull($pedido->repartidor_id);
    }

    public function test_si_el_repartidor_lo_suelta_el_plazo_vuelve_a_empezar(): void
    {
        $pedido = $this->pedidoListo();
        $this->travel(20)->minutes();
        $repartidor = $this->aceptar($pedido);
        $this->travel(5)->minutes();
        FlujoPedido::soltar($pedido, $repartidor);

        // 25 min desde que quedó listo, pero solo 20 desde que lo soltaron.
        $this->travel(20)->minutes();
        $this->vencer();
        $this->assertSame('listo', $pedido->refresh()->estado);

        $this->travel(11)->minutes();
        $this->vencer();
        $this->assertSame('cancelado', $pedido->refresh()->estado);
    }

    public function test_listo_pagado_con_qr_se_reembolsa_al_cancelarse_solo(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto);
        $pedido->forceFill(['metodo_pago' => 'qr', 'referencia_pago' => CobroQr::nuevaReferencia()])->save();
        CobroQr::procesar($pedido);
        $this->llevarHastaListo($pedido);

        $this->travel(31)->minutes();
        $this->vencer();
        $pedido->refresh();
        $this->assertSame('cancelado', $pedido->estado);
        $this->assertSame('reembolsado', $pedido->estado_pago);
    }

    public function test_el_sistema_no_toca_pedidos_en_otros_estados(): void
    {
        $preparando = $this->crearPedido($this->negocio, $this->producto);
        FlujoPedido::cambiar($preparando, 'confirmado', $this->negocio->usuario, 'comerciante');
        FlujoPedido::cambiar($preparando, 'preparando', $this->negocio->usuario, 'comerciante');
        $entregado = $this->entregarPedido($this->crearPedido($this->negocio, $this->producto));

        $this->travel(3)->hours();
        $this->vencer();
        $this->assertSame('preparando', $preparando->refresh()->estado);
        $this->assertSame('entregado', $entregado->refresh()->estado);
    }

    // ---------- El admin ----------

    public function test_el_admin_cancela_a_mano_un_pedido_listo_sin_repartidor(): void
    {
        Filament::setCurrentPanel('admin');
        $this->actingAs($this->crearUsuario(admin: true));
        $pedido = $this->pedidoListo(cantidad: 2);

        Livewire::test(ListPedidos::class)
            ->callAction(TestAction::make('cancelar')->table($pedido), data: ['motivo' => 'No hay repartidores en la zona'])
            ->assertNotified();

        $this->assertSame('cancelado', $pedido->refresh()->estado);
        $this->assertSame('No hay repartidores en la zona', $pedido->motivo_cancelacion);
        $this->assertSame(10, $this->producto->refresh()->stock);
    }

    // ---------- Comisión: sobre la venta, no sobre el envío ----------

    public function test_la_comision_es_el_8_por_ciento_de_los_productos_y_el_envio_es_del_repartidor(): void
    {
        DB::table('configuracion')->where('clave', 'comision_plataforma_pct')->update(['valor' => '8']);
        $producto = $this->crearProducto($this->negocio, ['precio' => 50, 'costo' => 30, 'stock' => 10]);
        Sanctum::actingAs($this->crearUsuario());

        $id = $this->postJson('/api/pedidos', [
            'negocio_id' => $this->negocio->id,
            'direccion' => 'Calle Libertad 123',
            'latitud' => -17.79,
            'longitud' => -63.18,
            'metodo_pago' => 'efectivo',
            'items' => [['producto_id' => $producto->id, 'cantidad' => 2]],
        ])->assertCreated()->json('id');

        $pedido = Pedido::find($id);
        $this->assertEquals(100, $pedido->subtotal);
        $this->assertGreaterThan(0, (float) $pedido->costo_envio);
        // 8 % de Bs 100 de productos; el envío no paga comisión.
        $this->assertEquals(8, $pedido->comision_plataforma);
        // El cliente no paga la comisión: el total es productos + envío.
        $this->assertEquals(100 + (float) $pedido->costo_envio, (float) $pedido->total);

        $repartidor = $this->crearRepartidor(placa: 'C-8');
        $this->entregarPedido($pedido, $repartidor);

        // Al entregar, la base anota la comisión como gasto del negocio.
        $this->assertEquals(8, RegistroComercio::where('pedido_id', $id)->where('tipo', 'comision')->value('egreso'));
        // El repartidor gana todo el envío.
        Sanctum::actingAs($repartidor);
        $this->getJson('/api/repartidor/entregas')
            ->assertOk()
            ->assertJsonPath('resumen.total_envios', number_format((float) $pedido->costo_envio, 2, '.', ''));
    }

    // ---------- La tarea automática ----------

    public function test_la_tarea_automatica_esta_programada(): void
    {
        Artisan::call('schedule:list');
        $this->assertStringContainsString('pedidos:vencer', Artisan::output());

        $pedido = $this->crearPedido($this->negocio, $this->producto);
        $this->travel(2)->minutes();
        $this->artisan('pedidos:vencer')
            ->expectsOutput('Rechazados sin respuesta: 1. Cancelados sin pago QR: 0. Cancelados sin repartidor: 0.')
            ->assertSuccessful();
        $this->assertSame('rechazado', $pedido->refresh()->estado);
    }

    // ---------- Ayudas ----------

    private function vencer(): void
    {
        $this->artisan('pedidos:vencer')->assertSuccessful();
    }

    private function plazo(string $clave, int $minutos): void
    {
        DB::table('configuracion')->updateOrInsert(['clave' => $clave], ['valor' => (string) $minutos, 'tipo' => 'int', 'updated_at' => now()]);
    }

    /** Pedido nuevo con QR, todavía sin pagar. */
    private function pedidoQr(int $cantidad = 1): Pedido
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto, $cantidad);
        $pedido->forceFill(['metodo_pago' => 'qr', 'referencia_pago' => CobroQr::nuevaReferencia()])->save();

        return $pedido->refresh();
    }

    /** Pedido que la tienda dejó listo (con el historial, como en la vida real). */
    private function pedidoListo(int $cantidad = 1): Pedido
    {
        $pedido = $this->crearPedido($this->negocio, $this->producto, $cantidad);
        $this->llevarHastaListo($pedido);

        return $pedido->refresh();
    }

    private function llevarHastaListo(Pedido $pedido): void
    {
        foreach (['confirmado', 'preparando', 'listo'] as $estado) {
            FlujoPedido::cambiar($pedido, $estado, $this->negocio->usuario, 'comerciante');
        }
    }

    private function aceptar(Pedido $pedido): Usuario
    {
        $usuario = $this->crearRepartidor(placa: 'R-'.$pedido->id);
        $perfil = Repartidor::find($usuario->id);
        FlujoPedido::aceptar($pedido, $perfil, $perfil->vehiculoAprobado());

        return $usuario;
    }
}
