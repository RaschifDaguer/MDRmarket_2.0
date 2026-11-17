<?php

namespace Tests\Feature;

use App\Filament\Resources\Configuraciones\Pages\ManageConfiguraciones;
use App\Filament\Resources\Reportes\Pages\ListReportes;
use App\Models\Configuracion;
use App\Models\MotivoReporte;
use App\Models\Negocio;
use App\Models\Notificacion;
use App\Models\Pedido;
use App\Models\Reporte;
use App\Support\FlujoPedido;
use Filament\Actions\Testing\TestAction;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Livewire\Livewire;
use Tests\TestCase;

/** Producto alistado, pantalla de reportes del panel y velocidad promedio en configuración. */
class PendientesFase2Test extends TestCase
{
    use DatabaseTransactions;

    private Negocio $negocio;

    protected function setUp(): void
    {
        parent::setUp();
        $this->negocio = $this->crearNegocio();
        DB::table('configuracion')->updateOrInsert(['clave' => 'velocidad_promedio_kmh'], ['valor' => '20', 'tipo' => 'decimal', 'updated_at' => now()]);
    }

    // ---------- Producto alistado ----------

    public function test_la_tienda_marca_y_desmarca_productos_alistados(): void
    {
        $pedido = $this->pedidoCon2Productos();
        $url = $this->urlAlistado($pedido);
        $item = $pedido->items()->first();

        Sanctum::actingAs($this->negocio->usuario);
        // Nuevo (sin aceptar): todavía no.
        $this->patchJson($url($item->id), ['alistado' => true])->assertUnprocessable()->assertJsonValidationErrors('alistado');

        foreach (['confirmado', 'preparando'] as $estado) {
            FlujoPedido::cambiar($pedido, $estado, $this->negocio->usuario, 'comerciante');
            $this->patchJson($url($item->id), ['alistado' => true])
                ->assertOk()->assertJsonPath('items.0.alistado', true)->assertJsonPath('items.1.alistado', false);
            $this->patchJson($url($item->id), ['alistado' => false])->assertOk()->assertJsonPath('items.0.alistado', false);
        }

        // Listo: ya no se toca.
        FlujoPedido::cambiar($pedido, 'listo', $this->negocio->usuario, 'comerciante');
        $this->patchJson($url($item->id), ['alistado' => true])
            ->assertUnprocessable()
            ->assertJsonPath('errors.alistado.0', 'Solo se marcan los productos de un pedido aceptado que estás alistando.');
    }

    public function test_solo_el_dueno_y_solo_productos_de_ese_pedido(): void
    {
        $pedido = $this->pedidoCon2Productos();
        FlujoPedido::cambiar($pedido, 'confirmado', $this->negocio->usuario, 'comerciante');
        $url = $this->urlAlistado($pedido);

        // Otro comerciante: no existe para él (404, como todo lo ajeno).
        Sanctum::actingAs($this->crearNegocio()->usuario);
        $this->patchJson($url($pedido->items()->first()->id), ['alistado' => true])->assertNotFound();

        // El cliente tampoco.
        Sanctum::actingAs($pedido->comprador);
        $this->patchJson($url($pedido->items()->first()->id), ['alistado' => true])->assertNotFound();

        // Un ítem de otro pedido.
        Sanctum::actingAs($this->negocio->usuario);
        $otro = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio));
        $this->patchJson($url($otro->items()->first()->id), ['alistado' => true])->assertNotFound();
        $this->patchJson($url($pedido->items()->first()->id), [])->assertUnprocessable()->assertJsonValidationErrors('alistado');
    }

    // ---------- Velocidad promedio ----------

    public function test_la_velocidad_promedio_cambia_el_tiempo_estimado(): void
    {
        $this->negocio->update(['tiempo_preparacion_min' => 10]);
        $tiempo = fn () => collect($this->getJson('/api/tiendas?latitud=-17.79&longitud=-63.18')->json('data'))
            ->firstWhere('id', $this->negocio->id)['envio']['tiempo_min'];

        $lento = $tiempo();
        DB::table('configuracion')->where('clave', 'velocidad_promedio_kmh')->update(['valor' => '60']);
        $rapido = $tiempo();

        $this->assertGreaterThan($rapido, $lento);
        $this->assertGreaterThanOrEqual(10, $rapido);
    }

    public function test_el_admin_edita_la_velocidad_entre_5_y_60(): void
    {
        Filament::setCurrentPanel('admin');
        $this->actingAs($this->crearUsuario(admin: true));
        $velocidad = Configuracion::find('velocidad_promedio_kmh');

        foreach (['4' => 'min', '61' => 'max'] as $valor => $regla) {
            Livewire::test(ManageConfiguraciones::class)
                ->callAction(TestAction::make('edit')->table($velocidad), data: ['valor' => $valor])
                ->assertHasFormErrors(['valor' => $regla]);
        }
        Livewire::test(ManageConfiguraciones::class)
            ->callAction(TestAction::make('edit')->table($velocidad), data: ['valor' => '22.5'])
            ->assertHasNoFormErrors();
        $this->assertSame('22.5', $velocidad->refresh()->valor);
    }

    // ---------- Reportes en el panel ----------

    public function test_el_admin_ve_filtra_y_resuelve_reportes(): void
    {
        Filament::setCurrentPanel('admin');
        $admin = $this->crearUsuario(admin: true);
        $abierto = $this->reporte('Faltó un producto');
        $otro = $this->reporte('Llegó frío', 'descartado');

        $this->actingAs($this->crearUsuario());
        $this->get('/admin/reportes')->assertForbidden();

        $this->actingAs($admin);
        $this->get('/admin/reportes')->assertOk()->assertSee('Faltó un producto');

        Livewire::test(ListReportes::class)
            ->assertCanSeeTableRecords([$abierto])
            ->assertCanNotSeeTableRecords([$otro]);   // pestaña "Abiertos"
        Livewire::test(ListReportes::class)
            ->set('activeTab', 'todos')
            ->filterTable('estado', 'descartado')
            ->assertCanSeeTableRecords([$otro])
            ->assertCanNotSeeTableRecords([$abierto]);

        Livewire::test(ListReportes::class)
            ->callAction(TestAction::make('resolver')->table($abierto), data: ['resolucion' => ''])
            ->assertHasFormErrors(['resolucion' => 'required']);
        Livewire::test(ListReportes::class)
            ->callAction(TestAction::make('resolver')->table($abierto), data: ['resolucion' => 'Te devolvemos el producto faltante.'])
            ->assertNotified();

        $abierto->refresh();
        $this->assertSame('resuelto', $abierto->estado);
        $this->assertSame($admin->id, (int) $abierto->revisado_por);
        $this->assertNotNull($abierto->revisado_en);
        $this->assertTrue(Notificacion::where('usuario_id', $abierto->reportante_id)->where('tipo', 'reporte_resuelto')
            ->where('cuerpo', 'Te devolvemos el producto faltante.')->exists());

        // Ya cerrado: sin botones.
        Livewire::test(ListReportes::class)->set('activeTab', 'todos')
            ->assertActionHidden(TestAction::make('resolver')->table($abierto));
    }

    public function test_descartar_un_reporte(): void
    {
        Filament::setCurrentPanel('admin');
        $this->actingAs($this->crearUsuario(admin: true));
        $reporte = $this->reporte('No me gustó');

        Livewire::test(ListReportes::class)
            ->callAction(TestAction::make('descartar')->table($reporte), data: ['resolucion' => 'El pedido llegó completo.'])
            ->assertNotified();
        $this->assertSame('descartado', $reporte->refresh()->estado);
    }

    // ---------- Ayudas ----------

    private function pedidoCon2Productos(): Pedido
    {
        $pedido = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio));
        $pedido->items()->create(['producto_id' => $this->crearProducto($this->negocio)->id, 'producto_nombre' => 'Otro', 'precio_unitario' => 5, 'cantidad' => 1]);

        return $pedido->refresh();
    }

    private function urlAlistado(Pedido $pedido): \Closure
    {
        return fn (int $item) => "/api/negocios/{$this->negocio->id}/pedidos/{$pedido->id}/items/$item/alistado";
    }

    /** Reporte del comprador de un pedido contra la tienda. */
    private function reporte(string $descripcion, string $estado = 'pendiente'): Reporte
    {
        $pedido = $this->crearPedido($this->negocio, $this->crearProducto($this->negocio));
        $reporte = Reporte::create([
            'reportante_id' => $pedido->comprador_id,
            'tipo' => 'negocio',
            'negocio_id' => $this->negocio->id,
            'motivo_id' => MotivoReporte::where('codigo', 'otro')->value('id'),
            'pedido_id' => $pedido->id,
            'descripcion' => $descripcion,
        ]);
        $reporte->forceFill(['estado' => $estado])->save();

        return $reporte->refresh();
    }
}
