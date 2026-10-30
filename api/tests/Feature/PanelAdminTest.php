<?php

namespace Tests\Feature;

use App\Filament\Resources\Documentos\Pages\ListDocumentos;
use App\Filament\Resources\Negocios\Pages\ListNegocios;
use App\Filament\Resources\Pedidos\Pages\ListPedidos;
use App\Filament\Resources\Repartidores\Pages\ListRepartidores;
use App\Filament\Widgets\Resumen;
use App\Models\Documento;
use App\Models\Notificacion;
use App\Models\Repartidor;
use Filament\Actions\Testing\TestAction;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Storage;
use Livewire\Livewire;
use Tests\TestCase;

/** Panel de administración (/admin): acceso, páginas y aprobaciones. */
class PanelAdminTest extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();
        Filament::setCurrentPanel('admin');
    }

    public function test_solo_entran_los_administradores(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');

        $this->actingAs($this->crearUsuario())->get('/admin')->assertForbidden();

        $this->actingAs($this->crearUsuario(admin: true))->get('/admin')->assertOk()->assertSee('MDR Market');
        // Las tarjetas del inicio se cargan aparte (después de la página).
        Livewire::test(Resumen::class)->assertSee('Negocios por revisar')->assertSee('Documentos por revisar');
    }

    public function test_todas_las_paginas_cargan(): void
    {
        $admin = $this->crearUsuario(admin: true);
        $negocio = $this->crearNegocio(estado: 'pendiente');
        $documento = $this->crearDocumento($negocio->usuario_id);

        $this->actingAs($admin);
        foreach ([
            '/admin', '/admin/negocios', "/admin/negocios/{$negocio->id}", '/admin/documentos',
            "/admin/documentos/{$documento->id}", '/admin/pedidos', '/admin/usuarios',
            '/admin/tarifas-envio', '/admin/configuracion',
        ] as $pagina) {
            $this->get($pagina)->assertOk();
        }
        $this->get("/admin/negocios/{$negocio->id}")->assertSee('Negocio de prueba')->assertSee('Carnet de identidad (anverso)');
    }

    public function test_aprobar_un_negocio_avisa_al_dueno(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $negocio = $this->crearNegocio(estado: 'pendiente');

        Livewire::test(ListNegocios::class)
            ->assertCanSeeTableRecords([$negocio])
            ->callAction(TestAction::make('aprobar')->table($negocio))
            ->assertNotified();

        $this->assertSame('aprobado', $negocio->refresh()->estado_verificacion);
        $this->assertTrue(Notificacion::where('usuario_id', $negocio->usuario_id)->where('tipo', 'negocio_aprobado')->exists());
    }

    public function test_rechazar_un_documento_pide_motivo(): void
    {
        $admin = $this->crearUsuario(admin: true);
        $this->actingAs($admin);
        $documento = $this->crearDocumento($this->crearUsuario()->id);

        Livewire::test(ListDocumentos::class)
            ->callAction(TestAction::make('rechazar')->table($documento), data: ['motivo' => ''])
            ->assertHasFormErrors(['motivo' => 'required']);

        Livewire::test(ListDocumentos::class)
            ->callAction(TestAction::make('rechazar')->table($documento), data: ['motivo' => 'La foto está borrosa'])
            ->assertNotified();

        $documento->refresh();
        $this->assertSame('rechazado', $documento->estado);
        $this->assertSame('La foto está borrosa', $documento->observacion);
        $this->assertSame($admin->id, $documento->revisado_por);
    }

    public function test_el_admin_puede_cancelar_un_pedido_en_curso(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio, ['stock' => 5]);
        $pedido = $this->crearPedido($negocio, $producto, 2);
        $this->assertSame(3, $producto->refresh()->stock);

        Livewire::test(ListPedidos::class)
            ->callAction(TestAction::make('cancelar')->table($pedido), data: ['motivo' => 'Pedido duplicado'])
            ->assertNotified();

        $this->assertSame('cancelado', $pedido->refresh()->estado);
        // La base devuelve el stock al cancelar.
        $this->assertSame(5, $producto->refresh()->stock);
    }

    public function test_las_fotos_de_documentos_son_privadas(): void
    {
        Storage::fake('local');
        $documento = $this->crearDocumento($this->crearUsuario()->id);
        Storage::disk('local')->put($documento->archivo_url, 'imagen');
        $url = route('panel.documento.archivo', $documento);

        $this->get($url)->assertForbidden();
        $this->actingAs($this->crearUsuario())->get($url)->assertForbidden();
        $this->actingAs($this->crearUsuario(admin: true))->get($url)->assertOk();
    }

    public function test_los_dos_lados_del_carnet_son_una_sola_solicitud(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $persona = $this->crearUsuario()->id;
        $anverso = $this->crearDocumento($persona);
        $reverso = $this->crearDocumento($persona, tipo: 2);
        $licencia = $this->crearDocumento($persona, tipo: 4);

        Livewire::test(ListDocumentos::class)
            ->assertCanSeeTableRecords([$anverso, $licencia])
            ->assertCanNotSeeTableRecords([$reverso])
            ->assertSee('Carnet de identidad (ambos lados)');

        $this->get("/admin/documentos/{$anverso->id}")
            ->assertOk()
            ->assertSee('Carnet de identidad (anverso)')
            ->assertSee('Carnet de identidad (reverso)');

        Livewire::test(ListDocumentos::class)
            ->callAction(TestAction::make('aprobar')->table($anverso))
            ->assertNotified();

        $this->assertSame('aprobado', $anverso->refresh()->estado);
        $this->assertSame('aprobado', $reverso->refresh()->estado);
        $this->assertSame('pendiente', $licencia->refresh()->estado);
    }

    public function test_rechazar_solo_un_lado_del_carnet(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $persona = $this->crearUsuario()->id;
        $anverso = $this->crearDocumento($persona);
        $reverso = $this->crearDocumento($persona, tipo: 2);

        // Solo el reverso está mal: ese se rechaza y el anverso queda aprobado.
        Livewire::test(ListDocumentos::class)
            ->callAction(TestAction::make('rechazar')->table($anverso), data: ['lados' => ['reverso'], 'motivo' => 'No se lee el número'])
            ->assertNotified();

        $this->assertSame('aprobado', $anverso->refresh()->estado);
        $this->assertSame('rechazado', $reverso->refresh()->estado);
        $this->assertSame('No se lee el número', $reverso->observacion);
        $this->assertSame(
            ['Vuelve a subir: Carnet de identidad (reverso)'],
            Notificacion::where('usuario_id', $persona)->where('tipo', 'documento_rechazado')->pluck('titulo')->all()
        );
    }

    public function test_rechazar_los_dos_lados_deja_un_solo_aviso(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $persona = $this->crearUsuario()->id;
        $anverso = $this->crearDocumento($persona);
        $reverso = $this->crearDocumento($persona, tipo: 2);

        Livewire::test(ListDocumentos::class)
            ->callAction(TestAction::make('rechazar')->table($anverso), data: ['lados' => ['anverso', 'reverso'], 'motivo' => 'Foto borrosa'])
            ->assertNotified();

        $this->assertSame('rechazado', $anverso->refresh()->estado);
        $this->assertSame('rechazado', $reverso->refresh()->estado);
        $this->assertSame(
            ['Vuelve a subir: Carnet de identidad (ambos lados)'],
            Notificacion::where('usuario_id', $persona)->where('tipo', 'documento_rechazado')->pluck('titulo')->all()
        );
    }

    public function test_la_selfie_se_revisa_junto_al_carnet(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $persona = $this->crearUsuario()->id;
        $anverso = $this->crearDocumento($persona);
        $reverso = $this->crearDocumento($persona, tipo: 2);
        $rostro = $this->crearDocumento($persona, tipo: 8);

        Livewire::test(ListDocumentos::class)
            ->assertCanSeeTableRecords([$anverso])
            ->assertCanNotSeeTableRecords([$reverso, $rostro])
            ->assertSee('Carnet de identidad (ambos lados) y foto del rostro');

        $this->get("/admin/documentos/{$anverso->id}")
            ->assertOk()
            ->assertSee('Foto del rostro (selfie)')
            ->assertSee('Revisa que la cara de la selfie sea la misma persona');

        // La cara no coincide: se rechaza solo la selfie y el carnet queda aprobado.
        Livewire::test(ListDocumentos::class)
            ->callAction(TestAction::make('rechazar')->table($anverso), data: ['lados' => ['rostro'], 'motivo' => 'La cara no coincide con el carnet'])
            ->assertNotified();

        $this->assertSame('aprobado', $anverso->refresh()->estado);
        $this->assertSame('aprobado', $reverso->refresh()->estado);
        $this->assertSame('rechazado', $rostro->refresh()->estado);
        $this->assertSame(
            ['Vuelve a subir: Foto del rostro (selfie)'],
            Notificacion::where('usuario_id', $persona)->where('tipo', 'documento_rechazado')->pluck('titulo')->all()
        );

        // La nueva selfie (con el carnet ya aprobado) es una solicitud aparte.
        $nueva = $this->crearDocumento($persona, tipo: 8);
        Livewire::test(ListDocumentos::class)
            ->assertCanSeeTableRecords([$nueva])
            ->assertSee('Foto del rostro (selfie)');
    }

    public function test_las_paginas_de_repartidores_cargan(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $repartidor = $this->repartidorEnRevision();
        $this->crearDocumento($repartidor->usuario_id);

        $this->get('/admin/repartidores')->assertOk()->assertSee('Moto 1111-PRB');
        $this->get("/admin/repartidores/{$repartidor->usuario_id}")
            ->assertOk()
            ->assertSee('1111-PRB')
            ->assertSee('R-12345')
            ->assertSee('Carnet de identidad (anverso)');
    }

    public function test_aprobar_un_repartidor_aprueba_su_vehiculo_y_le_avisa(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $repartidor = $this->repartidorEnRevision();

        Livewire::test(ListRepartidores::class)
            ->assertCanSeeTableRecords([$repartidor])
            ->callAction(TestAction::make('aprobar')->table($repartidor))
            ->assertNotified();

        $repartidor->refresh();
        $this->assertSame('aprobado', $repartidor->estado_verificacion);
        $this->assertNotNull($repartidor->verificado_en);
        $this->assertSame('aprobado', $repartidor->vehiculos()->first()->estado_verificacion);
        $this->assertTrue(Notificacion::where('usuario_id', $repartidor->usuario_id)->where('tipo', 'repartidor_aprobado')->exists());
    }

    public function test_rechazar_un_repartidor_pide_motivo(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $repartidor = $this->repartidorEnRevision();

        Livewire::test(ListRepartidores::class)
            ->callAction(TestAction::make('rechazar')->table($repartidor), data: ['motivo' => ''])
            ->assertHasFormErrors(['motivo' => 'required']);
        $this->assertSame('pendiente', $repartidor->refresh()->estado_verificacion);

        Livewire::test(ListRepartidores::class)
            ->callAction(TestAction::make('rechazar')->table($repartidor), data: ['motivo' => 'La placa no coincide con la foto'])
            ->assertNotified();

        $this->assertSame('rechazado', $repartidor->refresh()->estado_verificacion);
        $this->assertSame('rechazado', $repartidor->vehiculos()->first()->estado_verificacion);
        $this->assertSame(
            ['La placa no coincide con la foto'],
            Notificacion::where('usuario_id', $repartidor->usuario_id)->where('tipo', 'repartidor_rechazado')->pluck('cuerpo')->all()
        );
    }

    public function test_sin_vehiculo_no_se_puede_aprobar(): void
    {
        $this->actingAs($this->crearUsuario(admin: true));
        $repartidor = Repartidor::create(['usuario_id' => $this->crearUsuario()->id])->refresh();

        Livewire::test(ListRepartidores::class)
            ->assertActionDisabled(TestAction::make('aprobar')->table($repartidor));
    }

    /** Repartidor en revisión con una moto. */
    private function repartidorEnRevision(): Repartidor
    {
        $repartidor = Repartidor::create(['usuario_id' => $this->crearUsuario()->id]);
        $repartidor->vehiculos()->create(['tipo_vehiculo_id' => 1, 'placa' => '1111-PRB', 'ruat' => 'R-12345']);

        return $repartidor->refresh();
    }

    private function crearDocumento(int $usuarioId, int $tipo = 1): Documento
    {
        return Documento::create([
            'usuario_id' => $usuarioId,
            'tipo_documento_id' => $tipo,
            'archivo_url' => "documentos/{$usuarioId}/{$tipo}.png",
        ])->refresh();
    }
}
