<?php

namespace Tests\Feature;

use App\Filament\Resources\Configuraciones\Pages\ManageConfiguraciones;
use App\Models\Configuracion;
use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\Producto;
use App\Models\Repartidor;
use App\Models\Reporte;
use App\Models\Resena;
use App\Models\Usuario;
use Carbon\CarbonImmutable;
use Filament\Actions\Testing\TestAction;
use Filament\Facades\Filament;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Fase 2 (API para las pantallas nuevas): reseña al repartidor con etiquetas,
 * con cuánto paga, ahorro, resumen del comercio, ganancias del repartidor,
 * tiendas con la ubicación del cliente, notificaciones, reportar un problema,
 * varias fotos por producto y repartidores cerca.
 */
class Fase2ApiTest extends TestCase
{
    use DatabaseTransactions;

    private Negocio $negocio;

    /** Ubicación de un cliente dentro de la cobertura (cerca del negocio de prueba). */
    private const CLIENTE = ['latitud' => -17.79, 'longitud' => -63.18];

    protected function setUp(): void
    {
        parent::setUp();
        $this->negocio = $this->crearNegocio();
        DB::table('configuracion')->updateOrInsert(['clave' => 'umbral_poco_stock'], ['valor' => '5', 'tipo' => 'int', 'updated_at' => now()]);
    }

    // ---------- Reseña al repartidor con etiquetas ----------

    public function test_el_cliente_califica_al_repartidor_con_etiquetas(): void
    {
        [$pedido, $repartidor] = $this->pedidoEntregado();
        Sanctum::actingAs($pedido->comprador);

        $this->putJson('/api/resenas', [
            'tipo' => 'repartidor', 'repartidor_id' => $repartidor->id, 'estrellas' => 5,
            'comentario' => 'Muy rápido', 'etiquetas' => ['Puntual', 'Cuidó el paquete'],
        ])->assertCreated()->assertJsonPath('tipo', 'repartidor')->assertJsonPath('etiquetas', ['Puntual', 'Cuidó el paquete']);

        // Lo edita (una sola reseña por repartidor).
        $this->putJson('/api/resenas', ['tipo' => 'repartidor', 'repartidor_id' => $repartidor->id, 'estrellas' => 4, 'etiquetas' => ['Amable']])
            ->assertOk()->assertJsonPath('etiquetas', ['Amable']);
        $this->assertSame(1, Resena::where('autor_id', $pedido->comprador_id)->where('tipo', 'repartidor')->count());

        // La base recalcula su calificación.
        $this->assertEquals(4, Repartidor::find($repartidor->id)->rating_promedio);

        // En el detalle del pedido, "mis reseñas" trae la del repartidor.
        $this->getJson("/api/pedidos/{$pedido->id}")
            ->assertJsonPath('mis_resenas.repartidor_id', $repartidor->id)
            ->assertJsonPath('mis_resenas.repartidor.estrellas', 4)
            ->assertJsonPath('mis_resenas.repartidor.etiquetas', ['Amable']);
    }

    public function test_las_etiquetas_son_solo_para_el_repartidor_y_de_la_lista(): void
    {
        [$pedido, $repartidor] = $this->pedidoEntregado();
        Sanctum::actingAs($pedido->comprador);

        $this->putJson('/api/resenas', ['tipo' => 'negocio', 'negocio_id' => $this->negocio->id, 'estrellas' => 5, 'etiquetas' => ['Amable']])
            ->assertUnprocessable()
            ->assertJsonPath('errors.etiquetas.0', 'Las etiquetas son solo para calificar al repartidor.');
        $this->putJson('/api/resenas', ['tipo' => 'repartidor', 'repartidor_id' => $repartidor->id, 'estrellas' => 5, 'etiquetas' => ['Rapidísimo']])
            ->assertUnprocessable()->assertJsonValidationErrors('etiquetas.0');

        // Tampoco se puede saltar la regla escribiendo directo en la base.
        $this->putJson('/api/resenas', ['tipo' => 'negocio', 'negocio_id' => $this->negocio->id, 'estrellas' => 5])->assertCreated();
        $this->expectException(QueryException::class);
        DB::table('resena')->where('autor_id', $pedido->comprador_id)->where('tipo', 'negocio')->update(['etiquetas' => '["Amable"]']);
    }

    public function test_no_califica_a_un_repartidor_que_no_le_llevo_nada(): void
    {
        $otro = $this->crearRepartidor(placa: 'OTRO-1');
        Sanctum::actingAs($this->crearUsuario());

        $this->putJson('/api/resenas', ['tipo' => 'repartidor', 'repartidor_id' => $otro->id, 'estrellas' => 1])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Solo puedes reseñar después de recibir un pedido');
    }

    // ---------- Con cuánto paga (efectivo) ----------

    public function test_paga_con_en_efectivo_muestra_el_cambio(): void
    {
        $producto = $this->crearProducto($this->negocio, ['precio' => 20, 'stock' => 10]);
        Sanctum::actingAs($this->crearUsuario());

        $pedido = $this->postJson('/api/pedidos', $this->datosPedido($producto, ['paga_con' => 100]))
            ->assertCreated()
            ->assertJsonPath('paga_con', '100.00');
        $total = (float) $pedido->json('total');
        $this->assertEquals(number_format(100 - $total, 2, '.', ''), $pedido->json('cambio'));

        // El negocio (y después el repartidor) también lo ven, para llevar cambio.
        Sanctum::actingAs($this->negocio->usuario);
        $this->getJson("/api/negocios/{$this->negocio->id}/pedidos/{$pedido->json('id')}")
            ->assertJsonPath('paga_con', '100.00')
            ->assertJsonPath('cambio', $pedido->json('cambio'));
    }

    public function test_paga_con_tiene_que_cubrir_el_total_y_solo_en_efectivo(): void
    {
        $producto = $this->crearProducto($this->negocio, ['precio' => 20, 'stock' => 10]);
        Sanctum::actingAs($this->crearUsuario());

        $this->postJson('/api/pedidos', $this->datosPedido($producto, ['paga_con' => 20]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('paga_con');
        $this->postJson('/api/pedidos', $this->datosPedido($producto, ['paga_con' => 100, 'metodo_pago' => 'qr']))
            ->assertUnprocessable()
            ->assertJsonPath('errors.paga_con.0', 'Con cuánto pagas solo se indica si pagas en efectivo.');
        // No se guardó nada ni se tocó el stock.
        $this->assertSame(10, $producto->refresh()->stock);

        // Sin paga_con (es opcional): pedido normal, sin cambio.
        $this->postJson('/api/pedidos', $this->datosPedido($producto))->assertCreated()
            ->assertJsonPath('paga_con', null)->assertJsonPath('cambio', null);
    }

    // ---------- Precio sin oferta y ahorro ----------

    public function test_el_pedido_guarda_el_precio_sin_oferta_y_lo_ahorrado(): void
    {
        $producto = $this->crearProducto($this->negocio, ['precio' => 20, 'precio_oferta' => 15, 'stock' => 10]);
        Sanctum::actingAs($this->crearUsuario());

        $pedido = $this->postJson('/api/pedidos', $this->datosPedido($producto, [], 3))->assertCreated();
        $pedido->assertJsonPath('items.0.precio_unitario', '15.00')
            ->assertJsonPath('items.0.precio_original', '20.00')
            ->assertJsonPath('ahorro', '15.00');

        // Lo llena la base (trg_pedido_item_bi), aunque el ítem se cree sin él.
        $directo = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio, ['precio' => 30, 'stock' => 5]));
        $this->assertEquals(30, $directo->items()->first()->precio_original);
    }

    // ---------- Resumen del comercio ----------

    public function test_resumen_del_comercio_compara_con_ayer_y_avisa_poco_stock(): void
    {
        $producto = $this->crearProducto($this->negocio, ['precio' => 50, 'stock' => 50]);
        $poco = $this->crearProducto($this->negocio, ['nombre' => 'Casi agotado', 'stock' => 3]);
        $this->crearProducto($this->negocio, ['nombre' => 'Agotado', 'stock' => 1])->update(['stock' => 0]);
        $this->crearProducto($this->negocio, ['nombre' => 'Mucho', 'stock' => 40]);

        $ahora = CarbonImmutable::now('America/La_Paz')->setTime(12, 0);
        // Ayer: una venta de Bs 100.
        $this->travelTo($ahora->subDay());
        $this->entregarPedido($this->crearPedido($this->negocio, $producto, 2));
        // Hoy: Bs 150, otro pedido en camino y uno rechazado (no cuenta).
        $this->travelTo($ahora);
        $this->entregarPedido($this->crearPedido($this->negocio, $producto, 3));
        $enCamino = $this->pedidoEnCamino($producto);
        $rechazado = $this->crearPedido($this->negocio, $producto);
        $rechazado->forceFill(['estado' => 'rechazado'])->save();

        Sanctum::actingAs($this->negocio->usuario);
        $this->getJson("/api/negocios/{$this->negocio->id}/resumen")
            ->assertOk()
            ->assertJsonPath('hoy.ventas', '150.00')
            ->assertJsonPath('ayer.ventas', '100.00')
            ->assertJsonPath('variacion_ventas_pct', 50)
            ->assertJsonPath('pedidos_hoy', 2)
            ->assertJsonPath('pedidos_en_camino', 1)
            ->assertJsonPath('umbral_poco_stock', 5)
            // Solo "Casi agotado" (3): el agotado (0) va aparte y los demás tienen de sobra.
            ->assertJsonPath('productos_poco_stock', 1)
            ->assertJsonPath('poco_stock.0.id', $poco->id)
            ->assertJsonPath('poco_stock.0.stock', 3)
            ->assertJsonPath('productos_sin_stock', 1);
        $this->assertSame('en_camino', $enCamino->refresh()->estado);
    }

    public function test_sin_ventas_ayer_no_hay_comparacion(): void
    {
        Sanctum::actingAs($this->negocio->usuario);
        $this->getJson("/api/negocios/{$this->negocio->id}/resumen")->assertJsonPath('variacion_ventas_pct', null);
    }

    // ---------- Ganancias y meta del repartidor ----------

    public function test_ganancias_del_repartidor_hoy_y_semana_con_meta(): void
    {
        $repartidor = $this->crearRepartidor(placa: 'GAN-1');
        $producto = $this->crearProducto($this->negocio, ['stock' => 20]);
        // Miércoles 18-nov-2026: la semana va del lunes 16 al domingo 22.
        $miercoles = CarbonImmutable::parse('2026-11-18 12:00', 'America/La_Paz');
        $this->travelTo($miercoles->subDays(2));          // lunes
        $this->entregarPedido($this->crearPedido($this->negocio, $producto), $repartidor);
        $this->travelTo($miercoles->subDays(7));          // semana pasada: no cuenta
        $this->entregarPedido($this->crearPedido($this->negocio, $producto), $repartidor);
        $this->travelTo($miercoles);                      // hoy, dos
        $this->entregarPedido($this->crearPedido($this->negocio, $producto), $repartidor);
        $this->entregarPedido($this->crearPedido($this->negocio, $producto), $repartidor);

        Sanctum::actingAs($repartidor);
        $this->putJson('/api/repartidor/meta', ['meta_diaria' => 0])->assertUnprocessable();
        $this->putJson('/api/repartidor/meta', ['meta_diaria' => 20])->assertOk()->assertJsonPath('meta_diaria', '20.00');

        // Cada envío de prueba es de Bs 5.
        $this->getJson('/api/repartidor/ganancias')
            ->assertOk()
            ->assertJsonPath('hoy.entregas', 2)
            ->assertJsonPath('hoy.ganado', '10.00')
            ->assertJsonPath('semana.desde', '2026-11-16')
            ->assertJsonPath('semana.entregas', 3)
            ->assertJsonPath('semana.ganado', '15.00')
            ->assertJsonCount(7, 'semana.por_dia')
            ->assertJsonPath('semana.por_dia.0.dia', 'L')
            ->assertJsonPath('semana.por_dia.0.ganado', '5.00')
            ->assertJsonPath('semana.por_dia.2.entregas', 2)
            ->assertJsonPath('semana.mejor_dia', '2026-11-18')
            ->assertJsonPath('progreso_meta_pct', 50)
            ->assertJsonPath('total_entregas', 4);

        // Sin meta.
        $this->putJson('/api/repartidor/meta', ['meta_diaria' => null])->assertOk()
            ->assertJsonPath('meta_diaria', null)->assertJsonPath('progreso_meta_pct', null);
    }

    public function test_ganancias_solo_para_repartidores(): void
    {
        Sanctum::actingAs($this->crearUsuario());
        $this->getJson('/api/repartidor/ganancias')->assertForbidden();
        $this->putJson('/api/repartidor/meta', ['meta_diaria' => 50])->assertForbidden();
    }

    // ---------- Tiendas con la ubicación del cliente ----------

    public function test_tiendas_con_ubicacion_traen_envio_distancia_y_tiempo(): void
    {
        $this->negocio->update(['tiempo_preparacion_min' => 10]);
        $lejos = $this->crearNegocio(datos: ['nombre' => 'Lejos', 'latitud' => -17.73, 'longitud' => -63.15]);

        $sin = $this->getJson('/api/tiendas')->assertOk();
        $this->assertArrayNotHasKey('envio', $sin->json('data.0'));

        $con = $this->getJson('/api/tiendas?'.http_build_query([...self::CLIENTE, 'orden' => 'cerca']))->assertOk();
        $tiendas = collect($con->json('data'))->keyBy('id');
        $cerca = $tiendas[$this->negocio->id]['envio'];
        $this->assertTrue($cerca['en_cobertura']);
        $this->assertGreaterThan(0, (float) $cerca['costo_envio']);
        $this->assertGreaterThan(0, $cerca['distancia_km']);
        $this->assertGreaterThanOrEqual(10, $cerca['tiempo_min']);
        $this->assertSame($cerca['tiempo_min'] + 10, $cerca['tiempo_max']);
        // "Cerca": la más cercana primero (entre las abiertas).
        $ids = array_column($con->json('data'), 'id');
        $this->assertLessThan(array_search($lejos->id, $ids), array_search($this->negocio->id, $ids));

        // Detalle de la tienda, con la misma ubicación.
        $this->getJson("/api/tiendas/{$this->negocio->id}?".http_build_query(self::CLIENTE))
            ->assertOk()->assertJsonPath('envio.costo_envio', $cerca['costo_envio']);
    }

    public function test_tiendas_fuera_de_cobertura_y_cerca_sin_ubicacion(): void
    {
        // La Paz: fuera de la cobertura de Santa Cruz.
        $fuera = $this->getJson('/api/tiendas?latitud=-16.5&longitud=-68.15')->assertOk();
        $envio = collect($fuera->json('data'))->firstWhere('id', $this->negocio->id)['envio'];
        $this->assertFalse($envio['en_cobertura']);
        $this->assertNull($envio['costo_envio']);

        $this->getJson('/api/tiendas?orden=cerca')->assertUnprocessable()->assertJsonValidationErrors('latitud');
        $this->getJson('/api/tiendas?latitud=-17.79')->assertUnprocessable()->assertJsonValidationErrors('longitud');
    }

    // ---------- Notificaciones ----------

    public function test_notificaciones_leer_una_y_todas(): void
    {
        $yo = $this->crearUsuario();
        $otro = $this->crearUsuario();
        Notificacion::avisar($yo->id, 'pedido_nuevo', 'Primera');
        Notificacion::avisar($yo->id, 'pedido_en_camino', 'Segunda', 'Va en camino');
        Notificacion::avisar($otro->id, 'pedido_nuevo', 'De otro');
        Sanctum::actingAs($yo);

        $lista = $this->getJson('/api/notificaciones')->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.titulo', 'Segunda')
            ->assertJsonPath('data.0.leida', false)
            ->assertJsonPath('meta.no_leidas', 2);

        $this->postJson('/api/notificaciones/'.$lista->json('data.0.id').'/leida')->assertOk()->assertJsonPath('leida', true);
        $this->getJson('/api/notificaciones?no_leidas=1')->assertJsonCount(1, 'data')->assertJsonPath('meta.no_leidas', 1);

        // La de otro usuario no existe para mí.
        $ajena = Notificacion::where('usuario_id', $otro->id)->value('id');
        $this->postJson("/api/notificaciones/$ajena/leida")->assertNotFound();

        $this->postJson('/api/notificaciones/leidas')->assertOk()->assertJsonPath('marcadas', 1);
        $this->getJson('/api/notificaciones')->assertJsonPath('meta.no_leidas', 0);
        $this->assertNull(Notificacion::find($ajena)->leida_en);
    }

    // ---------- Reportar un problema ----------

    public function test_reportar_un_problema_con_la_tienda_o_el_repartidor(): void
    {
        [$pedido, $repartidor] = $this->pedidoEntregado();
        Sanctum::actingAs($pedido->comprador);

        $motivos = $this->getJson('/api/motivos-reporte?tipo=repartidor')->assertOk()->json('*.codigo');
        $this->assertContains('conduccion_peligrosa', $motivos);
        $this->assertNotContains('negocio_fraudulento', $motivos);

        $this->postJson("/api/pedidos/{$pedido->id}/reportes", ['sobre' => 'negocio', 'motivo' => 'pedido_incompleto', 'descripcion' => 'Faltó un producto'])
            ->assertCreated()->assertJsonPath('sobre', 'negocio');
        $this->postJson("/api/pedidos/{$pedido->id}/reportes", ['sobre' => 'repartidor', 'motivo' => 'maltrato'])
            ->assertCreated();
        $this->assertSame(2, Reporte::where('pedido_id', $pedido->id)->count());
        $this->assertSame($repartidor->id, (int) Reporte::where('tipo', 'repartidor')->where('pedido_id', $pedido->id)->value('repartidor_id'));

        // Uno abierto por cada uno.
        $this->postJson("/api/pedidos/{$pedido->id}/reportes", ['sobre' => 'negocio', 'motivo' => 'otro'])
            ->assertUnprocessable()->assertJsonPath('errors.sobre.0', 'Ya nos contaste un problema con esta tienda. Lo estamos revisando.');
        // Motivo que no corresponde.
        $this->postJson("/api/pedidos/{$pedido->id}/reportes", ['sobre' => 'negocio', 'motivo' => 'conduccion_peligrosa'])
            ->assertUnprocessable()->assertJsonValidationErrors('motivo');
    }

    public function test_solo_el_comprador_reporta_y_sin_repartidor_no_se_lo_reporta(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio));
        Sanctum::actingAs($this->crearUsuario());
        $this->postJson("/api/pedidos/{$pedido->id}/reportes", ['sobre' => 'negocio', 'motivo' => 'otro'])->assertNotFound();

        Sanctum::actingAs($pedido->comprador);
        $this->postJson("/api/pedidos/{$pedido->id}/reportes", ['sobre' => 'repartidor', 'motivo' => 'maltrato'])
            ->assertUnprocessable()->assertJsonPath('errors.sobre.0', 'Este pedido no tuvo repartidor.');
    }

    // ---------- Varias fotos por producto ----------

    public function test_producto_con_varias_fotos_portada_y_borrar(): void
    {
        Storage::fake('public');
        $producto = $this->crearProducto($this->negocio);
        Sanctum::actingAs($this->negocio->usuario);
        $url = "/api/negocios/{$this->negocio->id}/productos/{$producto->id}";
        $datos = ['nombre' => $producto->nombre, 'categoria_id' => 101, 'precio' => 20, 'stock' => 10];

        $fotos = $this->post($url, [...$datos, 'fotos' => [$this->foto('a'), $this->foto('b'), $this->foto('c')]], ['Accept' => 'application/json'])
            ->assertOk()->assertJsonCount(3, 'imagenes')->json('imagenes');
        $this->assertTrue($fotos[0]['es_principal']);

        // Hasta 4: con dos más se pasa.
        $this->post($url, [...$datos, 'fotos' => [$this->foto('d'), $this->foto('e')]], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('fotos');
        $this->post($url, [...$datos, 'fotos' => [$this->foto('d')]], ['Accept' => 'application/json'])->assertOk()->assertJsonCount(4, 'imagenes');

        // Elegir otra portada.
        $this->postJson("$url/fotos/{$fotos[2]['id']}/portada")->assertOk()
            ->assertJsonPath('imagenes.0.id', $fotos[2]['id'])->assertJsonPath('imagenes.0.es_principal', true);
        $this->assertSame(1, $producto->imagenes()->where('es_principal', true)->count());

        // Borrar la portada: otra pasa a serlo.
        $this->deleteJson("$url/fotos/{$fotos[2]['id']}")->assertOk()->assertJsonCount(3, 'imagenes')
            ->assertJsonPath('imagenes.0.es_principal', true);
        $this->assertSame(1, $producto->imagenes()->where('es_principal', true)->count());
        // La lista del dueño trae todas las fotos (para editarlas).
        $lista = collect($this->getJson("/api/negocios/{$producto->negocio_id}/productos")->assertOk()->json());
        $this->assertCount(3, $lista->firstWhere('id', $producto->id)['imagenes']);

        // Una foto de otro producto no existe aquí.
        $otra = $this->crearProducto($this->negocio)->imagenes()->create(['url' => 'productos/x.png', 'es_principal' => true]);
        $this->deleteJson("$url/fotos/{$otra->id}")->assertNotFound();
    }

    // ---------- Repartidores cerca ----------

    public function test_el_negocio_ve_cuantos_repartidores_hay_cerca(): void
    {
        $pedido = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio));
        $pedido->forceFill(['estado' => 'listo'])->save();

        $cerca = $this->repartidorEn('C-1', -17.775, -63.194);                   // a unos metros del negocio
        $this->repartidorEn('C-2', -17.776, -63.195);                           // otro cerca
        $this->repartidorEn('L-1', -17.65, -63.10);                             // lejos (más de 5 km)
        $this->repartidorEn('V-1', -17.775, -63.194, minutosAtras: 30);         // ubicación vieja
        $this->repartidorEn('D-1', -17.775, -63.194, disponible: false);        // desconectado
        $this->repartidorEn('P-1', -17.775, -63.194, estado: 'pendiente');      // sin aprobar

        Sanctum::actingAs($this->negocio->usuario);
        $url = "/api/negocios/{$this->negocio->id}/pedidos";
        $this->getJson("$url/{$pedido->id}")->assertJsonPath('repartidores_cerca', 2);
        $this->getJson("$url?grupo=en_curso")->assertJsonPath('data.0.repartidores_cerca', 2);

        // Un pedido que necesita vehículo grande: las motos no cuentan.
        $pedido->forceFill(['categoria_vehiculo_requerida_id' => 3])->save();
        $this->getJson("$url/{$pedido->id}")->assertJsonPath('repartidores_cerca', 0);

        // Cuando ya lo tomó un repartidor, no se muestra.
        $pedido->forceFill(['categoria_vehiculo_requerida_id' => 1, 'repartidor_id' => $cerca->id])->save();
        $this->getJson("$url/{$pedido->id}")->assertJsonMissingPath('repartidores_cerca');

        // El cliente no lo ve.
        Sanctum::actingAs($pedido->comprador);
        $this->getJson("/api/pedidos/{$pedido->id}")->assertJsonMissingPath('repartidores_cerca');
    }

    // ---------- Panel: umbral de poco stock ----------

    public function test_el_admin_edita_el_umbral_de_poco_stock(): void
    {
        Filament::setCurrentPanel('admin');
        $this->actingAs($this->crearUsuario(admin: true));
        $umbral = Configuracion::find('umbral_poco_stock');

        Livewire::test(ManageConfiguraciones::class)
            ->assertCanSeeTableRecords([$umbral])
            ->callAction(TestAction::make('edit')->table($umbral), data: ['valor' => '2.5'])
            ->assertHasFormErrors(['valor' => 'integer']);
        Livewire::test(ManageConfiguraciones::class)
            ->callAction(TestAction::make('edit')->table($umbral), data: ['valor' => '8'])
            ->assertHasNoFormErrors();
        $this->assertSame('8', $umbral->refresh()->valor);
    }

    // ---------- Ayudas ----------

    /** @return array{0: Pedido, 1: Usuario} Pedido entregado y el usuario del repartidor que lo llevó. */
    private function pedidoEntregado(): array
    {
        $repartidor = $this->crearRepartidor(placa: 'ENT-'.random_int(100, 999));
        $pedido = $this->entregarPedido($this->crearPedido($this->negocio, $this->crearProducto($this->negocio)), $repartidor);

        return [$pedido->refresh(), $repartidor];
    }

    private function pedidoEnCamino(Producto $producto): Pedido
    {
        $pedido = $this->crearPedido($this->negocio, $producto);
        $pedido->forceFill(['estado' => 'en_camino'])->save();

        return $pedido;
    }

    private function datosPedido(Producto $producto, array $extra = [], int $cantidad = 1): array
    {
        return [
            'negocio_id' => $this->negocio->id,
            'direccion' => 'Calle Libertad 123',
            ...self::CLIENTE,
            'metodo_pago' => 'efectivo',
            'items' => [['producto_id' => $producto->id, 'cantidad' => $cantidad]],
            ...$extra,
        ];
    }

    private function foto(string $nombre): UploadedFile
    {
        return UploadedFile::fake()->image("$nombre.jpg", 400, 400);
    }

    private function repartidorEn(string $placa, float $lat, float $lng, int $minutosAtras = 1, bool $disponible = true, string $estado = 'aprobado'): Usuario
    {
        $usuario = $this->crearRepartidor(placa: $placa, estado: $estado, disponible: $disponible);
        Repartidor::find($usuario->id)->forceFill([
            'latitud_actual' => $lat, 'longitud_actual' => $lng, 'ubicacion_actualizada_en' => now()->subMinutes($minutosAtras),
        ])->save();

        return $usuario;
    }
}
