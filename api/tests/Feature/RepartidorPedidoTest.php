<?php

namespace Tests\Feature;

use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\RegistroComercio;
use App\Models\Repartidor;
use App\Models\Usuario;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Vista repartidor: pedidos disponibles, aceptar, recoger, entregar con el PIN. */
class RepartidorPedidoTest extends TestCase
{
    use DatabaseTransactions;

    private const CAMION = 5;

    private const GRANDE = 3;

    private Negocio $negocio;

    protected function setUp(): void
    {
        parent::setUp();
        $this->negocio = $this->crearNegocio();
    }

    public function test_flujo_completo_hasta_entregar_con_el_pin(): void
    {
        $repartidor = $this->crearRepartidor();
        $pedido = $this->pedidoListo();
        Sanctum::actingAs($repartidor);

        $this->assertContains($pedido->id, $this->disponibles());
        $this->getJson('/api/repartidor/pedidos-disponibles')
            ->assertJsonFragment(['id' => $pedido->id, 'costo_envio' => '5.00', 'tamano' => 'Liviano'])
            ->assertJsonMissing(['codigo_entrega' => '1234']);

        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")
            ->assertOk()
            ->assertJsonPath('repartidor.nombre', 'Diego Repartidor')
            ->assertJsonPath('repartidor.placa', '7777-MDR')
            ->assertJsonPath('cliente.nombre', 'Prueba Usuario')
            ->assertJsonPath('acciones', ['en_camino'])
            ->assertJsonMissingPath('codigo_entrega');
        $this->getJson('/api/repartidor/pedido-actual')->assertJsonPath('pedido.id', $pedido->id);
        $this->assertNotContains($pedido->id, $this->disponibles());

        // El cliente ve quién lo lleva; el negocio también, y ya no tiene acciones (va a buscarlo).
        Sanctum::actingAs($pedido->comprador);
        $this->getJson("/api/pedidos/{$pedido->id}")
            ->assertJsonPath('repartidor.vehiculo', 'Moto')
            ->assertJsonPath('repartidor.placa', '7777-MDR');
        Sanctum::actingAs($this->negocio->usuario);
        $this->getJson("/api/negocios/{$this->negocio->id}/pedidos/{$pedido->id}")
            ->assertJsonPath('repartidor.nombre', 'Diego Repartidor')
            ->assertJsonPath('acciones', []);

        // Lo recoge y lo entrega (con el PIN equivocado no se puede).
        Sanctum::actingAs($repartidor);
        $url = "/api/repartidor/pedidos/{$pedido->id}/estado";
        $this->putJson($url, ['estado' => 'entregado', 'codigo' => '1234'])->assertUnprocessable()->assertJsonValidationErrors('estado');
        $this->putJson($url, ['estado' => 'en_camino'])->assertOk()->assertJsonPath('estado', 'en_camino');
        $this->assertNotNull($pedido->refresh()->recogido_en);
        $this->putJson($url, ['estado' => 'entregado', 'codigo' => '9999'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.codigo.0', 'El PIN no coincide. Pídeselo de nuevo al cliente.');
        $this->putJson($url, ['estado' => 'entregado', 'codigo' => '1234'])
            ->assertOk()
            ->assertJsonPath('estado', 'entregado')
            ->assertJsonPath('estado_pago', 'pagado');

        // La base registró la venta y le sumó la entrega al repartidor.
        $this->assertTrue(RegistroComercio::where('pedido_id', $pedido->id)->where('tipo', 'venta')->exists());
        $this->assertSame(1, Repartidor::find($repartidor->id)->total_entregas);

        $this->getJson('/api/repartidor/pedido-actual')->assertExactJson(['pedido' => null]);
        $this->getJson('/api/repartidor/entregas')
            ->assertOk()
            ->assertJsonPath('data.0.id', $pedido->id)
            ->assertJsonPath('data.0.negocio.nombre', 'Negocio de prueba')
            ->assertJsonPath('data.0.costo_envio', '5.00')
            ->assertJsonPath('resumen.entregas', 1)
            ->assertJsonPath('resumen.total_envios', '5.00');

        // Avisos al cliente y al negocio en cada paso.
        foreach ([$pedido->comprador_id, $this->negocio->usuario_id] as $avisado) {
            $this->assertEqualsCanonicalizing(
                ['pedido_asignado', 'pedido_en_camino', 'pedido_entregado'],
                Notificacion::where('usuario_id', $avisado)->where('pedido_id', $pedido->id)->pluck('tipo')->all()
            );
        }
    }

    public function test_un_pedido_de_camion_no_le_aparece_a_una_moto(): void
    {
        $chico = $this->pedidoListo();
        $grande = $this->pedidoListo(categoria: self::GRANDE);

        Sanctum::actingAs($this->crearRepartidor());
        $this->assertContains($chico->id, $this->disponibles());
        $this->assertNotContains($grande->id, $this->disponibles());
        $this->postJson("/api/pedidos/{$grande->id}/aceptar")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pedido.0', 'Este pedido necesita un vehículo más grande.');

        // Un camión puede llevar los dos.
        Sanctum::actingAs($this->crearRepartidor(tipo: self::CAMION, placa: '8888-MDR'));
        $this->assertContains($chico->id, $this->disponibles());
        $this->assertContains($grande->id, $this->disponibles());
    }

    public function test_un_solo_pedido_a_la_vez(): void
    {
        [$primero, $segundo] = [$this->pedidoListo(), $this->pedidoListo()];
        Sanctum::actingAs($this->crearRepartidor());

        $this->postJson("/api/pedidos/{$primero->id}/aceptar")->assertOk();
        $this->postJson("/api/pedidos/{$segundo->id}/aceptar")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pedido.0', 'Ya tienes un pedido en curso. Entrégalo antes de aceptar otro.');
        $this->assertNull($segundo->refresh()->repartidor_id);
    }

    public function test_dos_repartidores_aceptan_el_mismo_pedido(): void
    {
        $pedido = $this->pedidoListo();
        $primero = $this->crearRepartidor();
        $segundo = $this->crearRepartidor(placa: '8888-MDR');

        Sanctum::actingAs($primero);
        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")->assertOk();
        Sanctum::actingAs($segundo);
        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pedido.0', 'Otro repartidor ya aceptó este pedido.');

        $this->assertSame($primero->id, $pedido->refresh()->repartidor_id);
    }

    public function test_soltar_antes_de_recogerlo(): void
    {
        $pedido = $this->pedidoListo();
        $repartidor = $this->crearRepartidor();
        Sanctum::actingAs($repartidor);

        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")->assertOk();
        $this->postJson("/api/pedidos/{$pedido->id}/soltar")->assertOk()->assertJsonPath('repartidor', null);

        $pedido->refresh();
        $this->assertNull($pedido->repartidor_id);
        $this->assertSame('listo', $pedido->estado);
        $this->assertTrue($pedido->historial()->where('motivo', 'El repartidor soltó el pedido')->exists());

        // Vuelve a estar disponible: otro lo toma. Una vez recogido ya no se puede soltar.
        Sanctum::actingAs($this->crearRepartidor(placa: '8888-MDR'));
        $this->assertContains($pedido->id, $this->disponibles());
        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")->assertOk();
        $this->putJson("/api/repartidor/pedidos/{$pedido->id}/estado", ['estado' => 'en_camino'])->assertOk();
        $this->postJson("/api/pedidos/{$pedido->id}/soltar")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pedido.0', 'Ya lo recogiste: ahora tienes que entregarlo.');
    }

    public function test_el_comerciante_nunca_lleva_ni_entrega(): void
    {
        // Regla de operaciones: todo pedido lo lleva un repartidor de la app.
        $conRepartidor = $this->pedidoListo();
        $sinRepartidor = $this->pedidoListo();
        Sanctum::actingAs($this->crearRepartidor());
        $this->postJson("/api/pedidos/{$conRepartidor->id}/aceptar")->assertOk();

        Sanctum::actingAs($this->negocio->usuario);
        $url = fn (Pedido $p) => "/api/negocios/{$this->negocio->id}/pedidos/{$p->id}/estado";
        $soloRepartidor = 'Solo el repartidor de la app recoge y entrega el pedido.';
        foreach ([$conRepartidor, $sinRepartidor] as $pedido) {
            $this->putJson($url($pedido), ['estado' => 'en_camino'])
                ->assertUnprocessable()
                ->assertJsonPath('errors.estado.0', $soloRepartidor);
            $this->putJson($url($pedido), ['estado' => 'entregado', 'codigo' => '1234'])
                ->assertUnprocessable()
                ->assertJsonPath('errors.estado.0', $soloRepartidor);
            $this->assertSame('listo', $pedido->refresh()->estado);
        }

        // Sin repartidor: "Buscando repartidor…" y solo puede cancelarlo.
        $detalle = "/api/negocios/{$this->negocio->id}/pedidos";
        $this->getJson("$detalle/{$sinRepartidor->id}")->assertJsonPath('acciones', ['cancelado'])->assertJsonPath('repartidor', null);
        // Con repartidor: ya va en camino a buscarlo, no tiene botones.
        $this->getJson("$detalle/{$conRepartidor->id}")->assertJsonPath('acciones', []);
        $this->putJson($url($conRepartidor), ['estado' => 'cancelado', 'motivo' => 'Sin stock'])->assertUnprocessable();
        $this->putJson($url($sinRepartidor), ['estado' => 'cancelado', 'motivo' => 'Sin stock'])->assertOk();
    }

    public function test_un_repartidor_no_ve_ni_toca_pedidos_de_otro(): void
    {
        $pedido = $this->pedidoListo();
        Sanctum::actingAs($this->crearRepartidor());
        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")->assertOk();

        Sanctum::actingAs($this->crearRepartidor(placa: '8888-MDR'));
        $this->getJson("/api/pedidos/{$pedido->id}")->assertNotFound();
        $this->putJson("/api/repartidor/pedidos/{$pedido->id}/estado", ['estado' => 'en_camino'])->assertNotFound();
        $this->postJson("/api/pedidos/{$pedido->id}/soltar")->assertNotFound();
        $this->getJson('/api/repartidor/pedido-actual')->assertExactJson(['pedido' => null]);
        $this->assertSame('listo', $pedido->refresh()->estado);
    }

    public function test_un_pendiente_un_sancionado_o_desconectado_no_ve_nada(): void
    {
        $pedido = $this->pedidoListo();

        // En revisión (como queda al registrarse).
        $pendiente = $this->crearRepartidor(estado: 'pendiente');
        Sanctum::actingAs($pendiente);
        $this->getJson('/api/repartidor/pedidos-disponibles')
            ->assertForbidden()
            ->assertJsonPath('message', 'Tu cuenta de repartidor todavía no está aprobada.');
        $this->putJson('/api/repartidor/disponible', ['disponible' => true])->assertForbidden();
        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")->assertForbidden();

        // Aprobado pero con una sanción vigente.
        $sancionado = $this->crearRepartidor(placa: '8888-MDR');
        DB::table('sancion')->insert([
            'usuario_id' => $sancionado->id, 'rol_afectado' => 'repartidor', 'tipo' => 'bloqueo',
            'motivo' => 'Reportes de clientes', 'created_at' => now(), 'updated_at' => now(),
        ]);
        Sanctum::actingAs($sancionado);
        $this->getJson('/api/repartidor/pedidos-disponibles')
            ->assertForbidden()
            ->assertJsonPath('message', 'Tu cuenta de repartidor está suspendida.');
        $this->postJson("/api/pedidos/{$pedido->id}/aceptar")->assertForbidden();

        // Aprobado pero desconectado; al ponerse en línea, ya ve los pedidos.
        Sanctum::actingAs($this->crearRepartidor(placa: '9999-MDR', disponible: false));
        $this->getJson('/api/repartidor/pedidos-disponibles')
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Ponte en línea para ver y aceptar pedidos.');
        $this->putJson('/api/repartidor/disponible', ['disponible' => true, 'latitud' => -17.78, 'longitud' => -63.18])
            ->assertOk()
            ->assertJsonPath('disponible', true);
        $this->assertContains($pedido->id, $this->disponibles());
        $this->getJson('/api/repartidor/pedidos-disponibles')
            ->assertJsonFragment(['id' => $pedido->id])
            ->assertJsonPath('0.distancia_al_negocio_km', fn ($km) => $km !== null);

        $this->assertNull($pedido->refresh()->repartidor_id);
    }

    public function test_no_lleva_sus_propios_pedidos(): void
    {
        $repartidor = $this->crearRepartidor();
        $propio = $this->pedidoListo(comprador: $repartidor);
        Sanctum::actingAs($repartidor);

        // Error encontrado probando a mano: si compraba con su misma cuenta, el
        // pedido no aparecía y no sabía por qué. Ahora aparece marcado como propio.
        $this->getJson('/api/repartidor/pedidos-disponibles')
            ->assertJsonFragment(['id' => $propio->id, 'propio' => true]);
        $this->postJson("/api/pedidos/{$propio->id}/aceptar")
            ->assertUnprocessable()
            ->assertJsonPath('errors.pedido.0', 'No puedes llevar un pedido tuyo o de tu negocio.');
    }

    /** Pedido que el negocio ya dejó "listo" (PIN 1234, envío Bs 5). */
    private function pedidoListo(int $categoria = 1, ?Usuario $comprador = null): Pedido
    {
        $pedido = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio), comprador: $comprador);
        $pedido->forceFill(['estado' => 'listo', 'categoria_vehiculo_requerida_id' => $categoria])->save();

        return $pedido->refresh();
    }

    /** Ids de los pedidos disponibles para quien tiene la sesión. */
    private function disponibles(): array
    {
        return $this->getJson('/api/repartidor/pedidos-disponibles')->assertOk()->json('*.id');
    }
}
