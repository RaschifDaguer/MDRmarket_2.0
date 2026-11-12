<?php

namespace Tests\Feature;

use App\Models\Notificacion;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Stock: aviso al agotarse, renovarlo y que el cliente vea los agotados. */
class StockTest extends TestCase
{
    use DatabaseTransactions;

    public function test_al_agotarse_avisa_al_negocio_y_el_cliente_lo_ve_agotado(): void
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio, ['nombre' => 'Salteña zzstock', 'stock' => 2]);
        Sanctum::actingAs($this->crearUsuario());

        // El pedido se lleva las 2 últimas.
        $this->postJson('/api/pedidos', [
            'negocio_id' => $negocio->id,
            'direccion' => 'Calle Libertad 123',
            'latitud' => -17.7895,
            'longitud' => -63.1803,
            'metodo_pago' => 'efectivo',
            'items' => [['producto_id' => $producto->id, 'cantidad' => 2]],
        ])->assertCreated();

        $this->assertSame(0, $producto->refresh()->stock);
        $aviso = Notificacion::where(['usuario_id' => $negocio->usuario_id, 'tipo' => 'stock_agotado'])->sole();
        $this->assertSame('Stock insuficiente: «Salteña zzstock» se agotó', $aviso->titulo);
        $this->assertSame('Renueva el producto (sube su stock) para seguir vendiéndolo.', $aviso->cuerpo);

        // El cliente lo sigue viendo en el catálogo, con stock 0 ("Agotado")…
        $this->getJson('/api/productos?q=zzstock')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.stock', 0);
        $this->getJson("/api/tiendas/{$negocio->id}")->assertJsonPath('productos.0.stock', 0);
        // …pero no lo puede pedir.
        $this->postJson('/api/pedidos', [
            'negocio_id' => $negocio->id,
            'direccion' => 'Calle Libertad 123',
            'latitud' => -17.7895,
            'longitud' => -63.1803,
            'metodo_pago' => 'efectivo',
            'items' => [['producto_id' => $producto->id, 'cantidad' => 1]],
        ])->assertUnprocessable()->assertJsonValidationErrors(['items.0.cantidad' => '«Salteña zzstock» se agotó.']);
    }

    public function test_el_negocio_ve_sus_agotados_y_renueva_el_stock(): void
    {
        $negocio = $this->crearNegocio();
        $agotado = $this->crearProducto($negocio, ['nombre' => 'Empanada', 'stock' => 0]);
        $this->crearProducto($negocio, ['nombre' => 'Refresco', 'stock' => 12]);
        Sanctum::actingAs($negocio->usuario);

        $this->getJson("/api/negocios/{$negocio->id}/resumen")
            ->assertOk()
            ->assertJsonPath('productos_sin_stock', 1)
            ->assertJsonPath('productos_agotados', ['Empanada'])
            ->assertJsonPath('unidades_en_stock', 12);

        // "Renovar stock".
        $url = "/api/negocios/{$negocio->id}/productos/{$agotado->id}/stock";
        $this->patchJson($url, ['stock' => -1])->assertUnprocessable()->assertJsonValidationErrors('stock');
        $this->patchJson($url, ['stock' => 30])->assertOk()->assertJsonPath('stock', 30);

        $this->getJson("/api/negocios/{$negocio->id}/resumen")
            ->assertJsonPath('productos_sin_stock', 0)
            ->assertJsonPath('productos_agotados', []);

        // Otro negocio no puede tocar el stock ajeno.
        $otro = $this->crearNegocio();
        Sanctum::actingAs($otro->usuario);
        $this->patchJson("/api/negocios/{$negocio->id}/productos/{$agotado->id}/stock", ['stock' => 1])->assertNotFound();
        $this->patchJson("/api/negocios/{$otro->id}/productos/{$agotado->id}/stock", ['stock' => 1])->assertNotFound();
    }
}
