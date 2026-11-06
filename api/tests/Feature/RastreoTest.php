<?php

namespace Tests\Feature;

use App\Models\Negocio;
use App\Models\Pedido;
use App\Models\Repartidor;
use App\Models\Usuario;
use App\Support\FlujoPedido;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Rastreo del pedido en el mapa: el repartidor manda su GPS y el cliente lo sigue. */
class RastreoTest extends TestCase
{
    use DatabaseTransactions;

    private Negocio $negocio;

    private Usuario $repartidor;

    protected function setUp(): void
    {
        parent::setUp();
        $this->negocio = $this->crearNegocio(); // en -17.7745, -63.1935
        $this->repartidor = $this->crearRepartidor();
    }

    public function test_tres_posiciones_y_el_cliente_ve_la_tercera(): void
    {
        $pedido = $this->pedidoEnCamino();
        Sanctum::actingAs($this->repartidor);

        // Del negocio hacia la casa del cliente (-17.79, -63.18).
        foreach ([[-17.7760, -63.1920], [-17.7800, -63.1880], [-17.7850, -63.1840]] as [$lat, $lng]) {
            $this->postJson('/api/repartidor/ubicacion', ['latitud' => $lat, 'longitud' => $lng])
                ->assertCreated()
                ->assertJsonPath('pedido_id', $pedido->id);
            $this->travel(4)->seconds();
        }
        $this->assertSame(-17.785, Repartidor::find($this->repartidor->id)->latitud_actual);

        Sanctum::actingAs($pedido->comprador);
        $seguimiento = $this->getJson("/api/pedidos/{$pedido->id}/seguimiento")
            ->assertOk()
            ->assertJsonPath('estado', 'en_camino')
            ->assertJsonPath('ubicacion_repartidor.latitud', -17.785)
            ->assertJsonPath('ubicacion_repartidor.longitud', -63.184)
            ->assertJsonPath('repartidor.nombre', 'Diego Repartidor')
            ->assertJsonPath('repartidor.placa', '7777-MDR')
            ->assertJsonPath('destino.latitud', -17.79)
            ->assertJsonPath('negocio.nombre', 'Negocio de prueba');
        // Falta poco más de 1 km: unos minutos a 25 km/h.
        $this->assertGreaterThan(0, $seguimiento->json('distancia_km'));
        $this->assertLessThan(3, $seguimiento->json('distancia_km'));
        $this->assertGreaterThanOrEqual(1, $seguimiento->json('tiempo_estimado_min'));
        $this->assertLessThanOrEqual(8, $seguimiento->json('tiempo_estimado_min'));

        // El negocio también lo puede seguir.
        Sanctum::actingAs($this->negocio->usuario);
        $this->getJson("/api/pedidos/{$pedido->id}/seguimiento")->assertOk()->assertJsonPath('ubicacion_repartidor.latitud', -17.785);
    }

    public function test_otro_cliente_no_ve_el_pedido(): void
    {
        $pedido = $this->pedidoEnCamino();
        Sanctum::actingAs($this->crearUsuario());
        $this->getJson("/api/pedidos/{$pedido->id}/seguimiento")->assertNotFound();

        // Ni otro repartidor.
        Sanctum::actingAs($this->crearRepartidor(placa: '8888-MDR'));
        $this->getJson("/api/pedidos/{$pedido->id}/seguimiento")->assertNotFound();
    }

    public function test_sin_pedido_activo_no_se_manda_la_ubicacion(): void
    {
        Sanctum::actingAs($this->repartidor);
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => -17.78, 'longitud' => -63.18])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Solo se manda la ubicación mientras llevas un pedido.');

        // Quien no es repartidor, tampoco.
        Sanctum::actingAs($this->crearUsuario());
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => -17.78, 'longitud' => -63.18])->assertForbidden();
    }

    public function test_al_entregar_ya_no_se_ve_donde_esta(): void
    {
        $pedido = $this->pedidoEnCamino();
        Sanctum::actingAs($this->repartidor);
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => -17.785, 'longitud' => -63.184])->assertCreated();
        FlujoPedido::cambiar($pedido, 'entregado', $this->repartidor, 'repartidor');

        Sanctum::actingAs($pedido->comprador);
        $this->getJson("/api/pedidos/{$pedido->id}/seguimiento")
            ->assertOk()
            ->assertJsonPath('estado', 'entregado')
            ->assertJsonPath('ubicacion_repartidor', null)
            ->assertJsonPath('repartidor', null)
            ->assertJsonPath('tiempo_estimado_min', null);

        // Y ya no puede mandar más (no lleva ningún pedido).
        Sanctum::actingAs($this->repartidor);
        $this->travel(4)->seconds();
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => -17.786, 'longitud' => -63.183])->assertUnprocessable();
    }

    public function test_coordenadas_invalidas_y_muy_seguidas_se_rechazan(): void
    {
        $this->pedidoEnCamino();
        Sanctum::actingAs($this->repartidor);

        foreach ([
            'latitud' => ['latitud' => 120, 'longitud' => -63.18],
            'longitud' => ['latitud' => -17.78, 'longitud' => 'abc'],
        ] as $campo => $malas) {
            $this->postJson('/api/repartidor/ubicacion', $malas)
                ->assertUnprocessable()
                ->assertJsonPath("errors.$campo.0", 'La ubicación no es válida.');
        }
        // GPS sin señal (0, 0) o sin datos.
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => 0, 'longitud' => 0])->assertUnprocessable()->assertJsonValidationErrors('latitud');
        $this->postJson('/api/repartidor/ubicacion', [])->assertUnprocessable()->assertJsonValidationErrors(['latitud', 'longitud']);

        // Una cada 3 segundos como máximo.
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => -17.78, 'longitud' => -63.18])->assertCreated();
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => -17.781, 'longitud' => -63.181])
            ->assertStatus(429)
            ->assertJsonPath('message', 'Espera unos segundos antes de mandar otra ubicación.');
        $this->travel(4)->seconds();
        $this->postJson('/api/repartidor/ubicacion', ['latitud' => -17.781, 'longitud' => -63.181])->assertCreated();
    }

    /** Pedido que el repartidor aceptó y ya recogió (en camino a -17.79, -63.18). */
    private function pedidoEnCamino(): Pedido
    {
        $pedido = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio));
        foreach (['confirmado', 'preparando', 'listo'] as $estado) {
            $pedido = FlujoPedido::cambiar($pedido, $estado, $this->negocio->usuario, 'comerciante');
        }
        $perfil = Repartidor::find($this->repartidor->id);
        $pedido = FlujoPedido::aceptar($pedido, $perfil, $perfil->vehiculoAprobado());

        return FlujoPedido::cambiar($pedido, 'en_camino', $this->repartidor, 'repartidor');
    }
}
