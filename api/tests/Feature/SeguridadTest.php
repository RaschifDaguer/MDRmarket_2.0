<?php

namespace Tests\Feature;

use App\Filament\Auth\AutenticadorApp;
use App\Http\Controllers\Api\PedidoController;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Pruebas de ataque: lo que intentaría alguien de afuera (sin sesión, con la
 * sesión de otro, con datos armados a mano o mandando solicitudes en masa).
 */
class SeguridadTest extends TestCase
{
    use DatabaseTransactions;

    public function test_las_rutas_privadas_piden_sesion(): void
    {
        foreach ([
            ['GET', '/api/me'], ['PUT', '/api/me'], ['GET', '/api/me/faltantes/cliente'],
            ['GET', '/api/documentos'], ['POST', '/api/documentos'],
            ['GET', '/api/direcciones'], ['POST', '/api/direcciones'], ['DELETE', '/api/direcciones/1'],
            ['GET', '/api/pedidos'], ['POST', '/api/pedidos'], ['GET', '/api/pedidos/1'], ['POST', '/api/pedidos/1/cancelar'],
            ['GET', '/api/negocios'], ['POST', '/api/negocios'], ['GET', '/api/negocios/1/resumen'],
            ['GET', '/api/negocios/1/pedidos'], ['PUT', '/api/negocios/1/pedidos/1/estado'],
            ['POST', '/api/negocios/1/productos'], ['PUT', '/api/resenas'], ['POST', '/api/auth/logout'],
            ['GET', '/api/tipos-vehiculo'], ['GET', '/api/repartidor'], ['POST', '/api/repartidor'], ['POST', '/api/vehiculos'],
            ['PUT', '/api/repartidor/disponible'], ['GET', '/api/repartidor/pedidos-disponibles'], ['GET', '/api/repartidor/pedido-actual'],
            ['POST', '/api/pedidos/1/aceptar'], ['POST', '/api/pedidos/1/soltar'], ['PUT', '/api/repartidor/pedidos/1/estado'],
            ['GET', '/api/repartidor/entregas'],
        ] as [$metodo, $ruta]) {
            $this->json($metodo, $ruta)
                ->assertUnauthorized()
                ->assertJsonPath('message', 'Tu sesión expiró o no iniciaste sesión.');
        }
    }

    public function test_un_token_inventado_o_vencido_no_sirve(): void
    {
        $this->withToken('1|inventado')->getJson('/api/me')->assertUnauthorized();

        $token = $this->crearUsuario()->createToken('app')->plainTextToken;
        $this->withToken($token)->getJson('/api/me')->assertOk();

        $this->travel(61)->days(); // la sesión de la app vence a los 60 días
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }

    public function test_no_se_ven_ni_tocan_datos_de_otros(): void
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio);
        $pedido = $this->crearPedido($negocio, $producto);
        Sanctum::actingAs($pedido->comprador);
        $direccion = $this->postJson('/api/direcciones', [
            'direccion' => 'Calle 1', 'latitud' => -17.7895, 'longitud' => -63.1803,
        ])->assertCreated()->json('id');

        // Otro usuario con su propio negocio cambia los números de la URL.
        $intruso = $this->crearUsuario();
        $suyo = $this->crearNegocio($intruso);
        Sanctum::actingAs($intruso);

        $this->getJson("/api/pedidos/{$pedido->id}")->assertNotFound();
        $this->postJson("/api/pedidos/{$pedido->id}/cancelar")->assertNotFound();
        $this->putJson("/api/direcciones/$direccion", ['direccion' => 'Robada'])->assertNotFound();
        $this->deleteJson("/api/direcciones/$direccion")->assertNotFound();

        $this->getJson("/api/negocios/{$negocio->id}/resumen")->assertNotFound();
        $this->getJson("/api/negocios/{$negocio->id}/pedidos")->assertNotFound();
        $this->putJson("/api/negocios/{$negocio->id}/pedidos/{$pedido->id}/estado", ['estado' => 'confirmado'])->assertNotFound();
        $this->patchJson("/api/negocios/{$negocio->id}/productos/{$producto->id}/disponible", ['disponible' => false])->assertNotFound();
        $this->deleteJson("/api/negocios/{$negocio->id}/productos/{$producto->id}")->assertNotFound();

        // Su negocio en la URL, pero el pedido y el producto de otro negocio.
        $this->getJson("/api/negocios/{$suyo->id}/pedidos/{$pedido->id}")->assertNotFound();
        $this->deleteJson("/api/negocios/{$suyo->id}/productos/{$producto->id}")->assertNotFound();

        $this->assertSame('pendiente', $pedido->refresh()->estado);
        $this->assertTrue((bool) $producto->refresh()->disponible);
        $this->assertDatabaseHas('direccion', ['id' => $direccion, 'direccion' => 'Calle 1']);
    }

    public function test_nadie_se_hace_administrador_desde_la_app(): void
    {
        $this->postJson('/api/auth/registro', [
            'nombre' => 'Pirata', 'apellido' => 'Prueba', 'email' => 'pirata.'.uniqid().'@mdrmarket.local',
            'ci_numero' => (string) random_int(10000000, 99999999),
            'password' => 'Secreta123', 'password_confirmation' => 'Secreta123',
            'es_admin' => true, 'activo' => true,
        ])->assertCreated()->assertJsonPath('usuario.es_admin', false);

        $usuario = $this->crearUsuario();
        Sanctum::actingAs($usuario);
        $this->putJson('/api/me', ['nombre' => 'Otro', 'es_admin' => 1, 'email' => 'cambiado@x.com'])->assertOk();
        $this->putJson('/api/me/vista', ['vista' => 'admin'])->assertUnprocessable();

        $usuario->refresh();
        $this->assertFalse((bool) $usuario->es_admin);
        $this->assertNotSame('cambiado@x.com', $usuario->email);
        $this->assertSame('Otro', $usuario->nombre);
    }

    public function test_el_panel_exige_verificacion_en_dos_pasos(): void
    {
        $admin = $this->crearUsuario(admin: true);
        $admin->saveAppAuthenticationSecret(null); // admin que todavía no la configuró

        $this->actingAs($admin)->get('/admin')
            ->assertRedirect('/admin/multi-factor-authentication/set-up');

        // El QR para escanear es una imagen SVG válida (no doblemente envuelta).
        Filament::setCurrentPanel('admin');
        $qr = AutenticadorApp::make()->generateQrCodeDataUri('JBSWY3DPEHPK3PXP');
        $this->assertStringStartsWith('data:image/svg+xml;base64,', $qr);
        $this->assertStringStartsWith('<?xml', base64_decode(substr($qr, strlen('data:image/svg+xml;base64,'))));

        // La clave del autenticador se guarda cifrada y nunca sale en el JSON.
        $admin->saveAppAuthenticationSecret('JBSWY3DPEHPK3PXP');
        $this->assertDatabaseMissing('usuario', ['id' => $admin->id, 'app_authentication_secret' => 'JBSWY3DPEHPK3PXP']);
        $this->assertArrayNotHasKey('app_authentication_secret', $admin->toArray());
    }

    public function test_la_documentacion_de_la_api_es_solo_para_administradores(): void
    {
        $this->get('/docs/api')->assertForbidden();
        $this->get('/docs/api.json')->assertForbidden();
        $this->actingAs($this->crearUsuario())->get('/docs/api')->assertForbidden();
        $this->actingAs($this->crearUsuario(admin: true))->get('/docs/api')->assertOk();

        // A quien no tiene sesión en el panel se lo manda al ingreso, sin error.
        $this->get('/login')->assertRedirect('/admin/login');
    }

    public function test_probar_contrasenas_se_bloquea(): void
    {
        $usuario = $this->crearUsuario();

        for ($i = 0; $i < 5; $i++) {
            // Cambiar la IP (falsificada) no sirve: también se cuenta por correo.
            $this->withHeader('X-Real-IP', "10.0.0.$i")
                ->postJson('/api/auth/login', ['email' => $usuario->email, 'password' => 'Adivina'.$i])
                ->assertUnprocessable();
        }

        $this->postJson('/api/auth/login', ['email' => strtoupper($usuario->email), 'password' => 'Secreta123'])
            ->assertTooManyRequests()
            ->assertHeader('Retry-After')
            ->assertJsonPath('message', 'Demasiadas solicitudes seguidas. Espera un momento y vuelve a intentar.');
    }

    public function test_solicitudes_en_masa_se_frenan(): void
    {
        Sanctum::actingAs($this->crearUsuario());

        // Pedidos falsos: más de 5 por minuto (aunque sean inválidos) → 429.
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/pedidos', [])->assertUnprocessable();
        }
        $this->postJson('/api/pedidos', [])->assertTooManyRequests();

        // Cualquier ruta: más de 120 por minuto → 429.
        Sanctum::actingAs($this->crearUsuario());
        for ($i = 0; $i < 120; $i++) {
            $this->getJson('/api/categorias')->assertOk();
        }
        $this->getJson('/api/categorias')->assertTooManyRequests();
    }

    public function test_maximo_de_pedidos_esperando_respuesta(): void
    {
        $negocio = $this->crearNegocio();
        $producto = $this->crearProducto($negocio, ['stock' => null]);
        $cliente = $this->crearUsuario();
        for ($i = 0; $i < PedidoController::MAXIMO_PENDIENTES; $i++) {
            $this->crearPedido($negocio, $producto, comprador: $cliente);
        }

        Sanctum::actingAs($cliente);
        $this->postJson('/api/pedidos', [
            'negocio_id' => $negocio->id, 'direccion' => 'Calle 1', 'latitud' => -17.7895, 'longitud' => -63.1803,
            'metodo_pago' => 'efectivo', 'items' => [['producto_id' => $producto->id, 'cantidad' => 1]],
        ])->assertUnprocessable()->assertJsonValidationErrors('pedido');
    }

    public function test_inyeccion_sql_no_funciona(): void
    {
        $this->crearProducto($this->crearNegocio(), ['nombre' => 'Salteña zzsql']);

        // % y _ son comodines de SQL: si no se escaparan, "zzsq_" encontraría "zzsql".
        foreach (["' OR '1'='1", "zzsql' UNION SELECT email, password FROM usuario -- ", 'zzsql%', 'zzsq_'] as $texto) {
            $this->getJson('/api/productos?q='.urlencode($texto))
                ->assertOk()
                ->assertJsonCount(0, 'data');
        }
        $this->getJson('/api/productos?orden='.urlencode('precio; DROP TABLE producto'))
            ->assertUnprocessable();
        $this->getJson('/api/productos/1%20OR%201=1')->assertNotFound();
    }

    public function test_las_fotos_publicas_no_dejan_leer_otros_archivos(): void
    {
        Storage::fake('public');
        Storage::disk('public')->put('productos/foto.jpg', 'imagen');
        Storage::disk('public')->put('productos/nota.txt', 'texto');

        $this->get('/api/archivos/productos/foto.jpg')->assertOk();
        $this->get('/api/archivos/productos/nota.txt')->assertNotFound();
        $this->get('/api/archivos/..%2F..%2F.env')->assertNotFound();
        $this->get('/api/archivos/productos/..%2F..%2F..%2F.env')->assertNotFound();
        $this->get('/api/archivos/..%5C..%5C.env')->assertNotFound();
        $this->get('/storage/app/private/documentos/1/carnet.jpg')->assertNotFound();
    }

    public function test_no_se_suben_programas_disfrazados_de_foto(): void
    {
        Storage::fake('local');
        Sanctum::actingAs($this->crearUsuario());

        // Archivo real (no el falso de Laravel, que dice su tipo según el nombre):
        // así se revisa el contenido, como en el servidor. Es un PHP inofensivo
        // (solo dice "hola"): uno de ataque de verdad lo borra el antivirus.
        $ruta = tempnam(sys_get_temp_dir(), 'mdr_prueba_');
        file_put_contents($ruta, "<?php echo 'hola';\n");
        $falsa = new UploadedFile($ruta, 'carnet.jpg', null, null, true);

        try {
            $this->post('/api/documentos', ['tipo' => 'ci_anverso', 'archivo' => $falsa], ['Accept' => 'application/json'])
                ->assertUnprocessable()
                ->assertJsonValidationErrors('archivo');

            $this->assertEmpty(Storage::disk('local')->allFiles());
        } finally {
            @unlink($ruta);
        }
    }

    public function test_cabeceras_de_seguridad(): void
    {
        $respuesta = $this->getJson('/api/categorias')->assertOk();

        $respuesta->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin')
            ->assertHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'")
            ->assertHeaderMissing('X-Powered-By');

        // El panel no se puede meter dentro de otra página (clickjacking).
        $this->get('/admin/login')->assertOk()->assertHeader('X-Frame-Options', 'DENY');
    }
}
