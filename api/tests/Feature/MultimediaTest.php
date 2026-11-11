<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Fotos, videos, audios y PDF de cada usuario (POST/GET/DELETE /api/multimedia). */
class MultimediaTest extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    public function test_sube_un_video_y_lo_ve_en_su_lista(): void
    {
        $usuario = $this->crearUsuario();
        Sanctum::actingAs($usuario);

        $subido = $this->post('/api/multimedia', ['archivo' => UploadedFile::fake()->create('paseo.mp4', 500, 'video/mp4')])
            ->assertCreated()
            ->assertJsonPath('data.tipo', 'video')
            ->json('data');

        $this->assertMatchesRegularExpression('/^[A-Za-z0-9]{40}\.mp4$/', $subido['nombre']);
        Storage::disk('public')->assertExists("multimedia/u{$usuario->id}/{$subido['nombre']}");
        $this->assertStringContainsString("/api/archivos/multimedia/u{$usuario->id}/", $subido['url']);

        $this->getJson('/api/multimedia')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.nombre', $subido['nombre'])
            ->assertJsonPath('max_mb', 90)
            ->assertJsonStructure(['usado_mb', 'cuota_mb', 'formatos' => ['imagen', 'video', 'audio', 'documento']]);
    }

    public function test_acepta_fotos_audios_y_pdf_con_su_tipo(): void
    {
        Sanctum::actingAs($this->crearUsuario());

        foreach ([
            ['foto.heic', 'image/heic', 'imagen', 'heic'],
            ['cancion.mp3', 'audio/mpeg', 'audio', 'mp3'],
            ['nota.m4a', 'audio/mp4', 'audio', 'm4a'],
            ['clip.mov', 'video/quicktime', 'video', 'mov'],
            ['menu.pdf', 'application/pdf', 'documento', 'pdf'],
        ] as [$nombre, $mime, $tipo, $extension]) {
            $nombreGuardado = $this->post('/api/multimedia', ['archivo' => UploadedFile::fake()->create($nombre, 50, $mime)])
                ->assertCreated()
                ->assertJsonPath('data.tipo', $tipo)
                ->json('data.nombre');
            $this->assertStringEndsWith('.'.$extension, $nombreGuardado, $nombre);
        }
    }

    public function test_rechaza_formatos_peligrosos(): void
    {
        Sanctum::actingAs($this->crearUsuario());

        // Páginas, SVG (pueden llevar scripts) y programas: nunca.
        foreach ([
            ['pagina.html', 'text/html'], ['dibujo.svg', 'image/svg+xml'], ['virus.php', 'application/x-php'],
            ['programa.exe', 'application/x-msdownload'], ['foto.jpg.php', 'image/jpeg'],
        ] as [$nombre, $mime]) {
            $this->post('/api/multimedia', ['archivo' => UploadedFile::fake()->create($nombre, 10, $mime)], ['Accept' => 'application/json'])
                ->assertUnprocessable()
                ->assertJsonValidationErrors('archivo');
        }
        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_respeta_el_tamano_maximo_y_la_cuota(): void
    {
        $usuario = $this->crearUsuario();
        Sanctum::actingAs($usuario);

        $this->post('/api/multimedia', ['archivo' => UploadedFile::fake()->create('largo.mp4', 91 * 1024, 'video/mp4')], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.archivo.0', 'El archivo pesa más de 90 MB.');

        // Ya tiene casi 1 MB guardado y la cuota es de 1 MB.
        config(['filesystems.multimedia.cuota_mb' => 1]);
        Storage::disk('public')->put("multimedia/u{$usuario->id}/".str_repeat('a', 40).'.mp4', str_repeat('x', 900 * 1024));

        $this->post('/api/multimedia', ['archivo' => UploadedFile::fake()->create('otro.mp4', 200, 'video/mp4')], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.archivo.0', 'Llegaste a tu límite de 1 MB. Borra algún archivo para subir otro.');
    }

    public function test_solo_borra_los_suyos(): void
    {
        $dueno = $this->crearUsuario();
        $otro = $this->crearUsuario();
        $nombre = str_repeat('b', 40).'.webm';
        Storage::disk('public')->put("multimedia/u{$dueno->id}/$nombre", 'video');

        Sanctum::actingAs($otro);
        $this->deleteJson("/api/multimedia/$nombre")->assertNotFound();
        $this->deleteJson('/api/multimedia/..%2F..%2F.env')->assertNotFound();
        $this->getJson('/api/multimedia')->assertOk()->assertJsonCount(0, 'data');
        Storage::disk('public')->assertExists("multimedia/u{$dueno->id}/$nombre");

        Sanctum::actingAs($dueno);
        $this->deleteJson("/api/multimedia/$nombre")->assertOk();
        Storage::disk('public')->assertMissing("multimedia/u{$dueno->id}/$nombre");
    }

    public function test_un_video_se_puede_ver_por_partes(): void
    {
        Storage::disk('public')->put('multimedia/u1/'.str_repeat('c', 40).'.mp4', '0123456789');
        $url = '/api/archivos/multimedia/u1/'.str_repeat('c', 40).'.mp4';

        $this->get($url)->assertOk()->assertHeader('Content-Type', 'video/mp4')->assertHeader('Accept-Ranges', 'bytes');
        $this->get($url, ['Range' => 'bytes=0-3'])->assertStatus(206)->assertHeader('Content-Range', 'bytes 0-3/10');

        // Lo que no es multimedia no se sirve, aunque exista.
        Storage::disk('public')->put('multimedia/u1/pagina.html', '<script>alert(1)</script>');
        $this->get('/api/archivos/multimedia/u1/pagina.html')->assertNotFound();
    }
}
