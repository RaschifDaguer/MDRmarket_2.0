<?php

namespace Tests\Feature;

use App\Filament\Resources\Configuraciones\Pages\ManageConfiguraciones;
use App\Models\Configuracion;
use Filament\Actions\Testing\TestAction;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use Tests\TestCase;

/** /admin/configuracion: el admin ve y edita los parámetros, validados por tipo y rango. */
class ConfiguracionPanelTest extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();
        Filament::setCurrentPanel('admin');
        // Las filas que agrega cambios/2026-11-16_plazos_de_pedidos.sql.
        foreach (['minutos_para_aceptar' => '1', 'minutos_para_pagar_qr' => '10', 'minutos_listo_sin_repartidor' => '30'] as $clave => $valor) {
            DB::table('configuracion')->updateOrInsert(['clave' => $clave], [
                'valor' => $valor, 'tipo' => 'int', 'descripcion' => "Plazo $clave", 'updated_at' => now(),
            ]);
        }
        DB::table('configuracion')->where('clave', 'comision_plataforma_pct')->update(['valor' => '8']);
    }

    public function test_solo_el_admin_entra(): void
    {
        $this->get('/admin/configuracion')->assertRedirect('/admin/login');

        $this->actingAs($this->crearUsuario());
        $this->get('/admin/configuracion')->assertForbidden();

        $this->actingAs($this->crearUsuario(admin: true));
        $this->get('/admin/configuracion')->assertOk();
    }

    public function test_el_admin_ve_la_comision_y_los_plazos(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));

        Livewire::test(ManageConfiguraciones::class)
            ->assertCanSeeTableRecords(Configuracion::whereIn('clave', [
                'comision_plataforma_pct', 'minutos_para_aceptar', 'minutos_para_pagar_qr', 'minutos_listo_sin_repartidor',
            ])->get())
            // Las coordenadas y la zona horaria no se tocan desde aquí.
            ->assertCanNotSeeTableRecords(Configuracion::whereIn('clave', ['centro_latitud', 'zona_horaria'])->get());
    }

    public function test_edita_un_plazo_entero(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $plazo = Configuracion::find('minutos_para_aceptar');

        Livewire::test(ManageConfiguraciones::class)
            ->callAction(TestAction::make('edit')->table($plazo), data: ['valor' => '3'])
            ->assertHasNoFormErrors();

        $this->assertSame('3', $plazo->refresh()->valor);
    }

    public function test_un_entero_no_acepta_decimales_ni_valores_fuera_de_rango(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $plazo = Configuracion::find('minutos_para_aceptar');

        foreach (['1.5' => 'integer', '0' => 'min', '61' => 'max', 'abc' => 'numeric'] as $valor => $regla) {
            Livewire::test(ManageConfiguraciones::class)
                ->callAction(TestAction::make('edit')->table($plazo), data: ['valor' => $valor])
                ->assertHasFormErrors(['valor' => $regla]);
        }
        $this->assertSame('1', $plazo->refresh()->valor);
    }

    public function test_la_comision_acepta_decimales_entre_0_y_100(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $comision = Configuracion::find('comision_plataforma_pct');

        Livewire::test(ManageConfiguraciones::class)
            ->callAction(TestAction::make('edit')->table($comision), data: ['valor' => '101'])
            ->assertHasFormErrors(['valor' => 'max']);
        $this->assertSame('8', $comision->refresh()->valor);

        Livewire::test(ManageConfiguraciones::class)
            ->callAction(TestAction::make('edit')->table($comision), data: ['valor' => '7.5'])
            ->assertHasNoFormErrors();
        $this->assertSame('7.5', $comision->refresh()->valor);
    }
}
