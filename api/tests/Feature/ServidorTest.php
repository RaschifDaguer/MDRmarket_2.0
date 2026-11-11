<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** Estado del servidor y qué pasa si la base de datos está apagada. Sin escribir en la base. */
class ServidorTest extends TestCase
{
    public function test_la_raiz_de_la_api_muestra_el_estado(): void
    {
        $this->getJson('/api')
            ->assertOk()
            ->assertJsonPath('estado', 'en línea')
            ->assertJsonPath('base_de_datos', 'conectada')
            ->assertJsonPath('fotos', 'disco local')
            ->assertJsonStructure(['documentacion', 'panel_admin']);
    }

    public function test_si_la_base_esta_apagada_responde_en_mantenimiento(): void
    {
        Route::get('prueba-sin-base', fn () => DB::select('select 1'));

        // Como cuando Aiven está dormido: nadie responde en ese puerto.
        config(['database.connections.mysql.port' => 1]);
        DB::purge('mysql');

        $this->getJson('/api/categorias')
            ->assertStatus(503)
            ->assertJsonPath('message', 'El servicio está en mantenimiento. Vuelve a intentar en unos minutos.');
        $this->get('/prueba-sin-base')->assertStatus(503)->assertSee('En mantenimiento');
        $this->getJson('/api')->assertOk()->assertJsonPath('base_de_datos', fn ($v) => str_starts_with($v, 'sin conexión'));
    }

    public function test_la_app_web_esta_publicada_en_app(): void
    {
        // La sirve Apache directo desde public/app (ver app/publicar_web.ps1).
        $index = public_path('app/index.html');
        $this->assertFileExists($index);
        $this->assertStringContainsString('<base href="/app/">', file_get_contents($index));
        $this->assertFileExists(public_path('app/main.dart.js'));
        $codigo = file_get_contents(public_path('app/main.dart.js'));
        // Nunca con una clave de Google sin restringir adentro (el repo es público).
        $this->assertDoesNotMatchRegularExpression('/AIza[0-9A-Za-z_\-]{35}/', $codigo);
        // Usa la API del mismo servidor desde donde se abre (Railway o la
        // universidad), no una dirección fija.
        $this->assertFalse(str_contains($codigo, 'up.railway.app'), 'La app web tiene fija la dirección de Railway: rearmarla con app/publicar_web.ps1.');
    }

    public function test_las_fotos_no_gastan_el_limite_general(): void
    {
        Storage::fake('public');
        Storage::disk('public')->put('productos/foto.jpg', 'imagen');

        // Un catálogo largo pide muchas fotos: más de las 120 por minuto del límite general.
        for ($i = 0; $i < 130; $i++) {
            $this->get('/api/archivos/productos/foto.jpg')->assertOk();
        }
        $this->getJson('/api/categorias')->assertOk();
    }
}
