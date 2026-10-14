<?php

namespace Tests\Feature;

use App\Filament\Resources\Documentos\Pages\ListDocumentos;
use App\Filament\Resources\Negocios\Pages\ListNegocios;
use App\Filament\Resources\Pedidos\Pages\ListPedidos;
use App\Filament\Widgets\Resumen;
use App\Models\Documento;
use App\Models\Notificacion;
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

    private function crearDocumento(int $usuarioId): Documento
    {
        return Documento::create([
            'usuario_id' => $usuarioId,
            'tipo_documento_id' => 1,
            'archivo_url' => "documentos/{$usuarioId}/ci.png",
        ])->refresh();
    }
}
