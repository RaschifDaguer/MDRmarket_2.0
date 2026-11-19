<?php

namespace Tests\Feature;

use App\Models\Documento;
use App\Models\Negocio;
use App\Models\Producto;
use App\Models\TipoDocumento;
use App\Support\PermisosNegocio;
use App\Support\ProductosRestringidos;
use App\Support\Terminos;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Términos y condiciones (mayor de 18), bebidas alcohólicas (+18 al comprar)
 * y permisos de licorerías y farmacias.
 */
class BebidasPermisosTest extends TestCase
{
    use DatabaseTransactions;

    private const CASA = ['latitud' => -17.7895, 'longitud' => -63.1803];

    // ---------- Términos y condiciones ----------

    public function test_crear_cuenta_exige_aceptar_los_terminos(): void
    {
        $datos = [
            'nombre' => 'Lucía', 'apellido' => 'Prueba', 'email' => 'lucia.'.uniqid().'@mdrmarket.local',
            'ci_numero' => (string) random_int(10000000, 99999999),
            'password' => 'Secreta123', 'password_confirmation' => 'Secreta123',
        ];

        $this->postJson('/api/auth/registro', $datos)->assertUnprocessable()->assertJsonValidationErrors('acepta_terminos');
        $this->postJson('/api/auth/registro', [...$datos, 'acepta_terminos' => false])->assertJsonValidationErrors('acepta_terminos');

        $this->postJson('/api/auth/registro', [...$datos, 'acepta_terminos' => true])
            ->assertCreated()
            ->assertJsonPath('usuario.terminos_pendientes', false);
        $this->assertDatabaseHas('usuario', ['email' => $datos['email'], 'terminos_version' => Terminos::VERSION]);
    }

    public function test_las_cuentas_antiguas_aceptan_los_terminos_en_la_app(): void
    {
        Sanctum::actingAs($usuario = $this->crearUsuario());
        $this->getJson('/api/me')->assertJsonPath('terminos_pendientes', true);

        $this->postJson('/api/me/terminos', ['acepta' => false])->assertJsonValidationErrors('acepta');
        $this->postJson('/api/me/terminos', ['acepta' => true])->assertOk()->assertJsonPath('terminos_pendientes', false);
        $this->assertNotNull($usuario->refresh()->terminos_aceptados_en);
    }

    public function test_los_terminos_se_ven_sin_cuenta(): void
    {
        $this->getJson('/api/terminos')
            ->assertOk()
            ->assertJsonPath('version', Terminos::VERSION)
            ->assertJsonFragment(['titulo' => '5. Bebidas alcohólicas y tabaco']);
        $this->get('/terminos')->assertOk()->assertSee('Términos y condiciones')->assertSee('mayores de 18', false);
    }

    // ---------- Comprar bebidas alcohólicas ----------

    public function test_las_bebidas_alcoholicas_se_marcan_en_el_catalogo(): void
    {
        $licoreria = $this->licoreriaAprobada();
        $cerveza = $this->crearProducto($licoreria, ['categoria_id' => 1401, 'nombre' => 'Cerveza Paceña 620 ml']);
        $refresco = $this->crearProducto($licoreria, ['categoria_id' => 103, 'nombre' => 'Refresco de mocochinchi']);

        $this->getJson("/api/productos/{$cerveza->id}")->assertJsonPath('solo_mayores', true);
        $this->getJson("/api/productos/{$refresco->id}")->assertJsonPath('solo_mayores', false);

        $categorias = collect($this->getJson('/api/categorias')->assertOk()->json());
        $this->assertTrue($categorias->firstWhere('id', 14)['solo_mayores']);
        $this->assertSame('alcohol', $categorias->firstWhere('id', 14)['permiso']);
        $this->assertSame('Bebidas', $categorias->firstWhere('id', 13)['nombre']);
    }

    public function test_comprar_alcohol_pide_confirmar_la_mayoria_de_edad(): void
    {
        $licoreria = $this->licoreriaAprobada();
        $cerveza = $this->crearProducto($licoreria, ['categoria_id' => 1401]);
        $refresco = $this->crearProducto($licoreria, ['categoria_id' => 103]);
        Sanctum::actingAs($this->crearUsuario());

        // Sin bebidas alcohólicas no se pregunta nada.
        $this->pedir($licoreria, [[$refresco, 1]])->assertCreated()->assertJsonPath('solo_mayores', false);

        // Dos confirmaciones: "soy mayor de 18" y la declaración de compra.
        $this->pedir($licoreria, [[$cerveza, 2]])->assertJsonValidationErrors('confirma_mayor_edad');
        $this->pedir($licoreria, [[$cerveza, 2]], ['confirma_mayor_edad' => true])->assertJsonValidationErrors('acepta_declaracion');
        $pedido = $this->pedir($licoreria, [[$cerveza, 2]], ['confirma_mayor_edad' => true, 'acepta_declaracion' => true])
            ->assertCreated()
            ->assertJsonPath('solo_mayores', true);
        $this->assertDatabaseHas('pedido', ['id' => $pedido->json('id'), 'solo_mayores' => 1]);
    }

    public function test_el_tabaco_tambien_es_solo_para_mayores(): void
    {
        $tienda = $this->crearNegocio();
        $cigarrillos = $this->crearProducto($tienda, ['categoria_id' => 1501, 'nombre' => 'Cigarrillos (cajetilla de 20)']);
        Sanctum::actingAs($this->crearUsuario());

        $this->getJson("/api/productos/{$cigarrillos->id}")->assertJsonPath('solo_mayores', true);
        $this->pedir($tienda, [[$cigarrillos, 1]])->assertJsonValidationErrors('confirma_mayor_edad');
        $this->pedir($tienda, [[$cigarrillos, 1]], ['confirma_mayor_edad' => true, 'acepta_declaracion' => true])
            ->assertCreated()
            ->assertJsonPath('solo_mayores', true);
    }

    // ---------- Detector de tabaco y alcohol al publicar ----------

    public function test_el_detector_reconoce_tabaco_y_alcohol(): void
    {
        $this->assertSame('tabaco', ProductosRestringidos::detectar('Cigarrillos Marlboro rojo')['tipo'] ?? null);
        $this->assertSame('tabaco', ProductosRestringidos::detectar('VAPE desechable sabor menta')['tipo'] ?? null);
        $this->assertSame('tabaco', ProductosRestringidos::detectar('Narguilé de vidrio')['tipo'] ?? null);
        $this->assertSame('alcohol', ProductosRestringidos::detectar('Singani Casa Real 750 ml')['tipo'] ?? null);
        $this->assertSame('alcohol', ProductosRestringidos::detectar('Six pack de CERVEZA')['tipo'] ?? null);

        // Sin falsas alarmas.
        $this->assertNull(ProductosRestringidos::detectar('Cerveza sin alcohol 0,0%'));
        $this->assertNull(ProductosRestringidos::detectar('Vinagre de vino tinto'));
        $this->assertNull(ProductosRestringidos::detectar('Alcohol en gel 70°'));
        $this->assertNull(ProductosRestringidos::detectar('Jugo de toronja natural'));
        $this->assertNull(ProductosRestringidos::detectar('Ronda de empanadas'));
    }

    public function test_tabaco_o_alcohol_en_otra_categoria_no_se_publica(): void
    {
        Storage::fake('public');
        $negocio = $this->crearNegocio();
        Sanctum::actingAs($negocio->usuario);
        $url = "/api/negocios/{$negocio->id}/productos";

        // Cigarrillos escondidos en "Supermercado": se piden en su categoría +18.
        $this->post($url, ['nombre' => 'Cigarrillos Marlboro', 'categoria_id' => 102, 'precio' => '20', 'stock' => '10'],
            ['Accept' => 'application/json'])
            ->assertJsonValidationErrors(['categoria_id' => 'Cigarrillos y tabaco']);
        $this->post($url, ['nombre' => 'Cigarrillos Marlboro', 'categoria_id' => 1501, 'precio' => '20', 'stock' => '10'],
            ['Accept' => 'application/json'])->assertCreated();

        // Singani como "refresco": se pide en Bebidas alcohólicas (y con permiso de licorería).
        $this->post($url, ['nombre' => 'Refresco', 'descripcion' => 'Con singani', 'categoria_id' => 103, 'precio' => '30', 'stock' => '5'],
            ['Accept' => 'application/json'])
            ->assertJsonValidationErrors(['categoria_id' => 'Bebidas alcohólicas']);
        $this->post($url, ['nombre' => 'Cerveza sin alcohol', 'categoria_id' => 103, 'precio' => '10', 'stock' => '5'],
            ['Accept' => 'application/json'])->assertCreated();
    }

    public function test_un_menor_de_edad_no_puede_comprar_alcohol(): void
    {
        $licoreria = $this->licoreriaAprobada();
        $cerveza = $this->crearProducto($licoreria, ['categoria_id' => 1401]);
        Sanctum::actingAs($this->crearUsuario(['fecha_nacimiento' => now()->subYears(16)->toDateString()]));

        $this->pedir($licoreria, [[$cerveza, 1]], ['confirma_mayor_edad' => true])
            ->assertJsonValidationErrors(['confirma_mayor_edad' => 'menores de 18']);
    }

    // ---------- Licorerías ----------

    public function test_una_licoreria_tiene_que_subir_sus_permisos(): void
    {
        Storage::fake('public');
        Sanctum::actingAs($dueno = $this->crearUsuario());

        // El rubro "Bebidas alcohólicas" ya es vender alcohol, aunque no marque la casilla.
        $id = $this->post('/api/negocios', [
            'nombre' => 'Licorería La Esquina', 'categoria_id' => 14, 'direccion' => 'Av. Busch 1234',
            'latitud' => -17.7745, 'longitud' => -63.1935, 'foto' => UploadedFile::fake()->image('local.jpg'),
        ], ['Accept' => 'application/json'])->assertCreated()->assertJsonPath('vende_alcohol', true)->json('id');

        $faltan = $this->getJson('/api/me/faltantes/comerciante')->json('faltantes.*.codigo');
        $this->assertContains("documento.autorizacion_alcohol:negocio$id", $faltan);
        $this->assertContains("documento.licencia_funcionamiento:negocio$id", $faltan);
        $this->assertNotContains("documento.resolucion_sedes:negocio$id", $faltan);
        $this->getJson('/api/me/faltantes/comerciante')->assertJsonFragment(['codigo' => "documento.licencia_funcionamiento:negocio$id",
            'negocio_id' => $id, 'ayuda' => TipoDocumento::where('codigo', 'licencia_funcionamiento')->value('descripcion')]);

        // Subidos (aunque estén en revisión) ya no figuran como faltantes.
        Storage::fake('local');
        foreach (['autorizacion_alcohol', 'licencia_funcionamiento'] as $tipo) {
            $this->post('/api/documentos', ['tipo' => $tipo, 'negocio_id' => $id, 'archivo' => UploadedFile::fake()->image("$tipo.jpg")],
                ['Accept' => 'application/json'])->assertCreated();
        }
        $this->assertEmpty(array_filter(
            $this->getJson('/api/me/faltantes/comerciante')->json('faltantes.*.codigo'),
            fn ($c) => str_contains($c, ':negocio'.$id)
        ));
        $this->assertSame(2, Documento::where('negocio_id', $id)->count());
        $this->assertSame((int) $dueno->id, (int) Negocio::find($id)->usuario_id);
    }

    public function test_sin_permiso_no_se_publican_bebidas_alcoholicas(): void
    {
        Storage::fake('public');
        $negocio = $this->crearNegocio();
        Sanctum::actingAs($negocio->usuario);
        $url = "/api/negocios/{$negocio->id}/productos";
        $cerveza = ['nombre' => 'Cerveza Huari', 'categoria_id' => 1401, 'precio' => '15', 'stock' => '24'];

        // No marcó "Vendo bebidas alcohólicas".
        $this->post($url, $cerveza, ['Accept' => 'application/json'])
            ->assertJsonValidationErrors(['categoria_id' => 'Vendo bebidas alcohólicas']);

        // La marcó, pero ya está aprobado (se ve en el catálogo) y sus permisos no.
        $negocio->forceFill(['vende_alcohol' => true])->save();
        $this->post($url, $cerveza, ['Accept' => 'application/json'])
            ->assertJsonValidationErrors(['categoria_id' => 'Autorización de expendio']);

        // Con los permisos aprobados, sí.
        $this->aprobarPermisos($negocio, 'alcohol');
        $this->post($url, $cerveza, ['Accept' => 'application/json'])->assertCreated();
    }

    public function test_quitar_el_permiso_solo_sin_productos_de_esa_categoria(): void
    {
        $licoreria = $this->licoreriaAprobada();
        $cerveza = $this->crearProducto($licoreria, ['categoria_id' => 1401]);
        Sanctum::actingAs($licoreria->usuario);
        $perfil = [
            'nombre' => $licoreria->nombre, 'categoria_id' => 1, 'direccion' => $licoreria->direccion,
            'latitud' => $licoreria->latitud, 'longitud' => $licoreria->longitud, 'vende_alcohol' => '0',
        ];

        $this->post("/api/negocios/{$licoreria->id}", $perfil, ['Accept' => 'application/json'])
            ->assertJsonValidationErrors('vende_alcohol');

        $cerveza->delete();
        $this->post("/api/negocios/{$licoreria->id}", $perfil, ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('vende_alcohol', false);
    }

    // ---------- Farmacias ----------

    public function test_una_farmacia_tiene_que_subir_sus_permisos(): void
    {
        Storage::fake('public');
        Sanctum::actingAs($this->crearUsuario());

        $id = $this->post('/api/negocios', [
            'nombre' => 'Farmacia Central', 'categoria_id' => 2, 'direccion' => 'Calle Junín 45',
            'latitud' => -17.7745, 'longitud' => -63.1935, 'es_farmacia' => '1',
            'foto' => UploadedFile::fake()->image('f.jpg'),
        ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('es_farmacia', true)
            ->assertJsonPath('vende_alcohol', false)
            ->json('id');

        $faltan = $this->getJson('/api/me/faltantes/comerciante')->json('faltantes.*.codigo');
        foreach (['resolucion_sedes', 'licencia_funcionamiento'] as $tipo) {
            $this->assertContains("documento.$tipo:negocio$id", $faltan);
        }
        $this->assertNotContains("documento.autorizacion_alcohol:negocio$id", $faltan);
    }

    public function test_solo_las_farmacias_publican_medicamentos(): void
    {
        Storage::fake('public');
        $negocio = $this->crearNegocio(estado: 'pendiente', datos: ['categoria_id' => 2]);
        Sanctum::actingAs($negocio->usuario);
        $url = "/api/negocios/{$negocio->id}/productos";
        $paracetamol = ['nombre' => 'Paracetamol 500 mg', 'categoria_id' => 201, 'precio' => '8', 'stock' => '50'];

        $this->post($url, $paracetamol, ['Accept' => 'application/json'])
            ->assertJsonValidationErrors(['categoria_id' => 'Solo las farmacias']);

        // En revisión: ya puede cargar su catálogo; el admin revisa los permisos antes de aprobarla.
        // Cada medicamento: confirma que se vende sin receta médica.
        $negocio->forceFill(['es_farmacia' => true])->save();
        $this->post($url, $paracetamol, ['Accept' => 'application/json'])
            ->assertJsonValidationErrors(['confirma_venta_libre' => 'sin receta']);
        $id = $this->post($url, [...$paracetamol, 'confirma_venta_libre' => '1'], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('venta_libre_confirmada', true)
            ->json('id');
        $this->assertNotNull(Producto::find($id)->venta_libre_confirmada_en);

        // Ya confirmado: al editarlo (precio, fotos…) no lo vuelve a pedir.
        $this->post("$url/$id", [...$paracetamol, 'precio' => '9'], ['Accept' => 'application/json'])->assertOk();
    }

    public function test_el_admin_ve_lo_que_falta_aprobar_de_una_farmacia(): void
    {
        $farmacia = $this->crearNegocio(estado: 'pendiente', datos: ['es_farmacia' => true]);

        $this->assertSame([
            'Licencia de funcionamiento municipal',
            'Resolución de apertura y funcionamiento (SEDES)',
        ], PermisosNegocio::pendientes($farmacia));

        $this->aprobarPermisos($farmacia, 'farmacia');
        $this->assertSame([], PermisosNegocio::pendientes($farmacia->refresh()));
    }

    // ---------- Ayudantes ----------

    private function licoreriaAprobada(): Negocio
    {
        $negocio = $this->crearNegocio(datos: ['categoria_id' => 14, 'vende_alcohol' => true]);
        $this->aprobarPermisos($negocio, 'alcohol');

        return $negocio;
    }

    /** Crea y aprueba los documentos de ese permiso (como si los hubiera revisado el admin). */
    private function aprobarPermisos(Negocio $negocio, string $permiso): void
    {
        foreach (PermisosNegocio::documentos($permiso) as $tipo) {
            $documento = Documento::create([
                'usuario_id' => $negocio->usuario_id,
                'tipo_documento_id' => $tipo->id,
                'negocio_id' => $negocio->id,
                'archivo_url' => "documentos/{$negocio->usuario_id}/{$tipo->codigo}.jpg",
            ]);
            $documento->forceFill(['estado' => 'aprobado'])->save();
        }
    }

    private function pedir(Negocio $negocio, array $items, array $extra = [])
    {
        return $this->postJson('/api/pedidos', [
            'negocio_id' => $negocio->id,
            'direccion' => 'Calle Libertad 123',
            ...self::CASA,
            'metodo_pago' => 'efectivo',
            'items' => array_map(fn ($i) => ['producto_id' => $i[0]->id, 'cantidad' => $i[1]], $items),
            ...$extra,
        ]);
    }
}
