<?php

namespace Tests\Feature;

use App\Models\Negocio;
use App\Models\Pedido;
use App\Models\Producto;
use App\Models\RegistroComercio;
use App\Models\Resena;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Lo que hace el comerciante en /api/negocios/{negocio}/… */
class ComercianteApiTest extends TestCase
{
    use DatabaseTransactions;

    private Negocio $negocio;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        $this->negocio = $this->crearNegocio();
        Sanctum::actingAs($this->negocio->usuario);
    }

    public function test_solo_el_dueno_entra_a_su_negocio(): void
    {
        Sanctum::actingAs($this->crearUsuario());
        $this->getJson("/api/negocios/{$this->negocio->id}/productos")->assertNotFound();
        $this->getJson("/api/negocios/{$this->negocio->id}/resumen")->assertNotFound();
    }

    public function test_crear_editar_y_ocultar_un_producto(): void
    {
        $url = "/api/negocios/{$this->negocio->id}/productos";
        $formulario = [
            'nombre' => 'Hamburguesa doble',
            'categoria_id' => 101,
            'precio' => '35',
            'costo' => '20',
            'controlar_stock' => '1',
            'stock' => '15',
            'foto' => UploadedFile::fake()->image('hamburguesa.jpg', 600, 600),
        ];

        $creado = $this->post($url, $formulario, ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('nombre', 'Hamburguesa doble')
            ->assertJsonPath('stock', 15)
            ->assertJsonPath('disponible', true);
        $this->assertStringContainsString('/api/archivos/productos/', $creado->json('imagen_url'));

        // Una categoría principal no sirve: tiene que ser una subcategoría.
        $this->post($url, [...$formulario, 'categoria_id' => 1], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('categoria_id');
        $this->post($url, [...$formulario, 'precio_oferta' => '40'], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('precio_oferta');

        // Editar: oferta y sin control de stock (comida al momento).
        $id = $creado->json('id');
        $this->post("$url/$id", [...$formulario, 'precio_oferta' => '30', 'controlar_stock' => '0', 'stock' => ''], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('precio_oferta', '30.00')
            ->assertJsonPath('en_oferta', true)
            ->assertJsonPath('stock', null);

        $this->patchJson("$url/$id/disponible", ['disponible' => false])->assertOk()->assertJsonPath('disponible', false);
        $this->getJson('/api/productos?negocio='.$this->negocio->id)->assertJsonCount(0, 'data'); // oculto en el catálogo
        $this->getJson($url)->assertOk()->assertJsonCount(1); // el dueño sí lo ve

        $this->deleteJson("$url/$id")->assertOk();
        $this->getJson($url)->assertJsonCount(0);
    }

    public function test_atender_un_pedido_hasta_entregarlo_con_el_pin(): void
    {
        $producto = $this->crearProducto($this->negocio, ['precio' => 25, 'costo' => 15, 'stock' => 10]);
        $pedido = $this->crearPedido($this->negocio, $producto, 2);
        $url = "/api/negocios/{$this->negocio->id}/pedidos";

        $this->getJson("$url?grupo=nuevos")->assertOk()->assertJsonPath('data.0.id', $pedido->id);
        $this->getJson("$url/{$pedido->id}")
            ->assertOk()
            ->assertJsonPath('acciones', ['confirmado', 'rechazado'])
            ->assertJsonMissingPath('codigo_entrega');

        // No se puede saltar pasos.
        $this->putJson("$url/{$pedido->id}/estado", ['estado' => 'listo'])
            ->assertUnprocessable()->assertJsonValidationErrors('estado');

        foreach (['confirmado', 'preparando', 'listo', 'en_camino'] as $estado) {
            $this->putJson("$url/{$pedido->id}/estado", ['estado' => $estado])->assertOk()->assertJsonPath('estado', $estado);
        }

        $this->putJson("$url/{$pedido->id}/estado", ['estado' => 'entregado', 'codigo' => '9999'])
            ->assertUnprocessable()->assertJsonPath('errors.codigo.0', 'El PIN no coincide. Pídeselo de nuevo al cliente.');
        $this->putJson("$url/{$pedido->id}/estado", ['estado' => 'entregado', 'codigo' => '1234'])
            ->assertOk()
            ->assertJsonPath('estado', 'entregado')
            ->assertJsonPath('estado_pago', 'pagado')
            ->assertJsonPath('acciones', []);

        // La base anotó la venta y la ganancia (2 × (25 − 15) = 20).
        $venta = RegistroComercio::where('pedido_id', $pedido->id)->where('tipo', 'venta')->first();
        $this->assertEquals(50, $venta->ingreso);
        $this->assertEquals(20, $venta->ganancia);

        $this->getJson("/api/negocios/{$this->negocio->id}/resumen")
            ->assertOk()
            ->assertJsonPath('hoy.ventas', '50.00')
            ->assertJsonPath('hoy.ganancia_bruta', '20.00')
            ->assertJsonPath('pedidos_nuevos', 0);
    }

    public function test_rechazar_pide_motivo_y_devuelve_el_stock(): void
    {
        $producto = $this->crearProducto($this->negocio, ['stock' => 5]);
        $pedido = $this->crearPedido($this->negocio, $producto, 3);
        $url = "/api/negocios/{$this->negocio->id}/pedidos/{$pedido->id}/estado";

        $this->putJson($url, ['estado' => 'rechazado'])->assertUnprocessable()->assertJsonValidationErrors('motivo');
        $this->putJson($url, ['estado' => 'rechazado', 'motivo' => 'Sin stock'])->assertOk()->assertJsonPath('motivo_cancelacion', 'Sin stock');

        $this->assertSame(5, $producto->refresh()->stock);
    }

    public function test_compras_y_gastos(): void
    {
        $producto = $this->crearProducto($this->negocio, ['stock' => 4, 'costo' => 10]);
        $url = "/api/negocios/{$this->negocio->id}/registros";

        $compra = $this->postJson($url, [
            'tipo' => 'compra', 'producto_id' => $producto->id, 'cantidad' => 6, 'costo_unitario' => 11, 'proveedor' => 'Mayorista',
        ])->assertCreated()->assertJsonPath('monto', '66.00');

        // La base sumó el stock y guardó el nuevo costo.
        $producto->refresh();
        $this->assertSame(10, $producto->stock);
        $this->assertEquals(11, $producto->costo);

        $this->postJson($url, ['tipo' => 'gasto', 'descripcion' => 'Luz de octubre', 'monto' => 120])->assertCreated();
        $this->postJson($url, ['tipo' => 'gasto', 'monto' => 10])->assertUnprocessable()->assertJsonValidationErrors('descripcion');
        $this->postJson($url, ['tipo' => 'compra', 'producto_id' => $this->crearProducto($this->crearNegocio())->id, 'cantidad' => 1, 'costo_unitario' => 1])
            ->assertUnprocessable()->assertJsonValidationErrors('producto_id');

        $this->getJson("$url?tipo=gasto")->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.monto', '120.00');

        // Borrar la compra resta lo que había sumado.
        $this->deleteJson("$url/".$compra->json('id'))->assertOk();
        $this->assertSame(4, $producto->refresh()->stock);

        $reporte = $this->getJson("/api/negocios/{$this->negocio->id}/reporte?agrupar=mes")->assertOk();
        $this->assertSame('120.00', $reporte->json('totales.gastos'));
        $this->assertSame('-120.00', $reporte->json('totales.ganancia_neta'));
    }

    public function test_responder_una_resena(): void
    {
        $producto = $this->crearProducto($this->negocio);
        $cliente = $this->crearUsuario();
        $pedido = $this->crearPedido($this->negocio, $producto, 1, $cliente);
        $pedido->forceFill(['estado' => 'entregado'])->save();
        $resena = Resena::create(['autor_id' => $cliente->id, 'tipo' => 'negocio', 'negocio_id' => $this->negocio->id, 'estrellas' => 3]);

        $this->getJson("/api/negocios/{$this->negocio->id}/resenas")
            ->assertOk()
            ->assertJsonPath('total_resenas', 1)
            ->assertJsonPath('por_estrellas.3', 1)
            ->assertJsonPath('data.0.estrellas', 3);

        $this->putJson("/api/negocios/{$this->negocio->id}/resenas/{$resena->id}/respuesta", ['respuesta' => '¡Gracias! Mejoraremos.'])
            ->assertOk()->assertJsonPath('respuesta', '¡Gracias! Mejoraremos.');

        // Una reseña de otro negocio no se puede responder desde aquí.
        $otra = Resena::create(['autor_id' => $cliente->id, 'tipo' => 'producto', 'producto_id' => $producto->id, 'estrellas' => 5]);
        $ajeno = $this->crearNegocio();
        Sanctum::actingAs($ajeno->usuario);
        $this->putJson("/api/negocios/{$ajeno->id}/resenas/{$otra->id}/respuesta", ['respuesta' => 'x'])->assertNotFound();
    }

    public function test_perfil_horario_y_abierto(): void
    {
        $url = "/api/negocios/{$this->negocio->id}";
        $perfil = [
            'nombre' => 'Pollos Marta', 'categoria_id' => 1, 'direccion' => 'Av. Cañoto 50',
            'latitud' => '-17.785', 'longitud' => '-63.19', 'tiempo_preparacion_min' => '25', 'pedido_minimo' => '20',
        ];

        $this->post($url, $perfil, ['Accept' => 'application/json'])
            ->assertOk()->assertJsonPath('nombre', 'Pollos Marta')->assertJsonPath('pedido_minimo', '20.00');
        $this->post($url, [...$perfil, 'latitud' => '-16.5', 'longitud' => '-68.15'], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('latitud');

        $this->patchJson("$url/abierto", ['abierto' => false])->assertOk()->assertJsonPath('abierto', false);

        $this->putJson("$url/horario", ['horarios' => [
            ['dia_semana' => 1, 'hora_apertura' => '08:00', 'hora_cierre' => '20:00'],
            ['dia_semana' => 6, 'hora_apertura' => '09:00', 'hora_cierre' => '13:00'],
        ]])->assertOk()->assertJsonCount(2, 'horarios')->assertJsonPath('horarios.1.hora_cierre', '13:00');

        $this->putJson("$url/horario", ['horarios' => [['dia_semana' => 2, 'hora_apertura' => '20:00', 'hora_cierre' => '08:00']]])
            ->assertUnprocessable()->assertJsonValidationErrors('horarios.0.hora_cierre');
    }
}
