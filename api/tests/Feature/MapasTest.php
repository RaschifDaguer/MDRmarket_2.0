<?php

namespace Tests\Feature;

use App\Http\Controllers\Api\RastreoController;
use App\Models\Configuracion;
use App\Support\Mapas\InstruccionesRuta;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Ruta por las calles (modo GPS y seguimiento) y dirección escrita del punto marcado. */
class MapasTest extends TestCase
{
    use DatabaseTransactions;

    /** Respuesta de OSRM: repartidor → tienda → casa, con 2 tramos. */
    private function osrm(): array
    {
        $paso = fn (string $tipo, ?string $mod, string $calle, array $linea, float $m, float $s, ?int $salida = null) => [
            'name' => $calle,
            'distance' => $m,
            'duration' => $s,
            'geometry' => ['coordinates' => $linea],
            'maneuver' => array_filter(['type' => $tipo, 'modifier' => $mod, 'location' => $linea[0], 'exit' => $salida]),
        ];

        return [
            'code' => 'Ok',
            'routes' => [[
                'distance' => 1200.0,
                'duration' => 120.0, // 36 km/h: más rápido que el promedio de 25 km/h
                'legs' => [
                    ['distance' => 500.0, 'duration' => 50.0, 'steps' => [
                        $paso('depart', 'right', 'Calle Libertad', [[-63.1900, -17.7800], [-63.1910, -17.7800]], 100, 10),
                        $paso('turn', 'left', 'Av. Busch', [[-63.1910, -17.7800], [-63.1910, -17.7790], [-63.1935, -17.7745]], 400, 40),
                        $paso('arrive', null, 'Av. Busch', [[-63.1935, -17.7745], [-63.1935, -17.7745]], 0, 0),
                    ]],
                    ['distance' => 700.0, 'duration' => 70.0, 'steps' => [
                        $paso('depart', null, 'Av. Busch', [[-63.1935, -17.7745], [-63.1900, -17.7850]], 300, 30),
                        $paso('roundabout', 'right', '', [[-63.1900, -17.7850], [-63.1800, -17.7900]], 400, 40, 2),
                        $paso('arrive', null, '', [[-63.1800, -17.7900], [-63.1800, -17.7900]], 0, 0),
                    ]],
                ],
            ]],
        ];
    }

    public function test_ruta_por_las_calles_con_pasos_en_espanol(): void
    {
        Http::fake(['routing.openstreetmap.de/*' => Http::response($this->osrm())]);
        Sanctum::actingAs($this->crearUsuario());

        $puntos = '-17.78,-63.19;-17.7745,-63.1935;-17.79,-63.18';
        $r = $this->getJson("/api/mapas/ruta?puntos={$puntos}&vehiculo=moto")->assertOk();

        // Una sola línea, sin repetir el punto donde se unen los pasos.
        $this->assertSame([-17.78, -63.19], $r->json('puntos.0'));
        $this->assertSame([-17.79, -63.18], $r->json('puntos.'.(count($r->json('puntos')) - 1)));
        $this->assertCount(6, $r->json('puntos'));
        $this->assertSame(1200, (int) $r->json('distancia_m'));
        // OSRM decía 120 s (36 km/h): se usa la velocidad promedio de la configuración (ej. 25 km/h = 173 s).
        $velocidad = (float) Configuracion::valor('velocidad_promedio_kmh', RastreoController::VELOCIDAD_KMH);
        $this->assertLessThan(36, $velocidad);
        $this->assertEqualsWithDelta(1.2 / $velocidad * 3600, $r->json('duracion_s'), 0.5);

        $this->assertSame('Sal por Calle Libertad', $r->json('pasos.0.instruccion'));
        $this->assertSame('Gira a la izquierda hacia Av. Busch', $r->json('pasos.1.instruccion'));
        $this->assertSame(1, $r->json('pasos.1.indice')); // la maniobra está en el 2.º punto
        $this->assertSame('Llegaste a tu destino', $r->json('pasos.2.instruccion'));
        $this->assertSame(1, $r->json('pasos.4.tramo'));
        $this->assertSame('En la rotonda, toma la 2.ª salida', $r->json('pasos.4.instruccion'));
        // Los tramos: dónde termina cada uno (la tienda y la casa).
        $this->assertSame(3, $r->json('tramos.0.indice_fin'));
        $this->assertSame(5, $r->json('tramos.1.indice_fin'));

        // La misma ruta otra vez (o casi desde el mismo lugar): sale de la caché.
        $this->getJson('/api/mapas/ruta?puntos=-17.780001,-63.190001;-17.7745,-63.1935;-17.79,-63.18')->assertOk();
        Http::assertSentCount(1);
        Http::assertSent(fn ($request) => str_contains($request->url(), '/routed-car/route/v1/driving/-63.19,-17.78;')
            && str_starts_with($request->header('User-Agent')[0] ?? '', 'MDRMarket/'));
    }

    public function test_en_bicicleta_usa_el_perfil_de_bicicleta(): void
    {
        Http::fake(['routing.openstreetmap.de/*' => Http::response($this->osrm())]);
        Sanctum::actingAs($this->crearUsuario());
        $this->getJson('/api/mapas/ruta?puntos=-17.78,-63.19;-17.79,-63.18&vehiculo=bicicleta')->assertOk();
        Http::assertSent(fn ($request) => str_contains($request->url(), '/routed-bike/'));
    }

    public function test_ruta_valida_los_puntos_y_pide_sesion(): void
    {
        Http::fake();
        $this->getJson('/api/mapas/ruta?puntos=-17.78,-63.19;-17.79,-63.18')->assertUnauthorized();

        Sanctum::actingAs($this->crearUsuario());
        $this->getJson('/api/mapas/ruta?puntos=-17.78,-63.19')->assertUnprocessable()->assertJsonValidationErrors('puntos');
        $this->getJson('/api/mapas/ruta?puntos=40.7,-74.0;-17.79,-63.18')->assertUnprocessable(); // Nueva York
        $this->getJson('/api/mapas/ruta?puntos=hola;-17.79,-63.18')->assertUnprocessable();
        $this->getJson('/api/mapas/ruta?puntos=-17.78,-63.19;-17.79,-63.18&vehiculo=avion')->assertUnprocessable();
        Http::assertNothingSent();
    }

    public function test_si_el_servicio_de_rutas_falla_responde_503(): void
    {
        Http::fake(['routing.openstreetmap.de/*' => Http::response('caído', 500)]);
        Sanctum::actingAs($this->crearUsuario());
        $this->getJson('/api/mapas/ruta?puntos=-17.78,-63.19;-17.79,-63.18')
            ->assertStatus(503)
            ->assertJsonPath('message', 'No se pudo calcular la ruta por las calles. Intenta en unos segundos.');
    }

    public function test_direccion_del_punto_marcado(): void
    {
        Http::fake(['nominatim.openstreetmap.org/*' => Http::response([
            'display_name' => 'Calle Libertad, Equipetrol, Santa Cruz de la Sierra, Bolivia',
            'address' => [
                'house_number' => '123',
                'road' => 'Calle Libertad',
                'neighbourhood' => 'Equipetrol',
                'city' => 'Santa Cruz de la Sierra',
                'country' => 'Bolivia',
            ],
        ])]);
        Sanctum::actingAs($this->crearUsuario());

        $this->getJson('/api/mapas/direccion?latitud=-17.765&longitud=-63.196')
            ->assertOk()
            ->assertJsonPath('calle', 'Calle Libertad 123')
            ->assertJsonPath('barrio', 'Equipetrol')
            ->assertJsonPath('corta', 'Calle Libertad 123, Equipetrol')
            ->assertJsonPath('texto', 'Calle Libertad 123, Equipetrol, Santa Cruz de la Sierra');

        // El mismo punto otra vez: de la caché (Nominatim pide no repetir consultas).
        $this->getJson('/api/mapas/direccion?latitud=-17.765&longitud=-63.196')->assertOk();
        Http::assertSentCount(1);
        Http::assertSent(fn ($request) => str_contains($request->url(), 'accept-language=es'));
    }

    public function test_direccion_sin_calle_usa_el_lugar_y_fuera_de_bolivia_no(): void
    {
        Http::fake(['nominatim.openstreetmap.org/*' => Http::response([
            'display_name' => 'Parque Urbano, Santa Cruz de la Sierra, Bolivia',
            'address' => ['leisure' => 'Parque Urbano', 'city' => 'Santa Cruz de la Sierra'],
        ])]);
        Sanctum::actingAs($this->crearUsuario());

        $this->getJson('/api/mapas/direccion?latitud=-17.79&longitud=-63.18')
            ->assertOk()
            ->assertJsonPath('corta', 'Parque Urbano')
            ->assertJsonPath('texto', 'Parque Urbano, Santa Cruz de la Sierra');
        $this->getJson('/api/mapas/direccion?latitud=48.85&longitud=2.35')->assertUnprocessable(); // París
    }

    public function test_si_el_servicio_de_direcciones_falla_responde_503(): void
    {
        Http::fake(['nominatim.openstreetmap.org/*' => Http::response('', 503)]);
        Sanctum::actingAs($this->crearUsuario());
        $this->getJson('/api/mapas/direccion?latitud=-17.70&longitud=-63.10')->assertStatus(503);
    }

    public function test_indicaciones_en_espanol(): void
    {
        $this->assertSame('Gira a la derecha hacia Av. Cañoto', InstruccionesRuta::texto('turn', 'right', 'Av. Cañoto'));
        $this->assertSame('Sigue derecho por 3er Anillo', InstruccionesRuta::texto('continue', 'straight', '3er Anillo'));
        $this->assertSame('Da la vuelta en U', InstruccionesRuta::texto('turn', 'uturn', null));
        $this->assertSame('Al final de la calle, gira a la izquierda', InstruccionesRuta::texto('end of road', 'left', ''));
        $this->assertSame('En la bifurcación, mantente a la derecha hacia Av. Banzer', InstruccionesRuta::texto('fork', 'slight right', 'Av. Banzer'));
        $this->assertSame('Sal de la rotonda por Av. Irala', InstruccionesRuta::texto('exit roundabout', 'right', 'Av. Irala'));
        $this->assertSame('Continúa por Calle Sucre', InstruccionesRuta::texto('new name', 'straight', 'Calle Sucre'));
        $this->assertSame('Sal hacia tu destino', InstruccionesRuta::texto('depart', null, null));
    }
}
