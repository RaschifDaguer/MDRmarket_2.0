<?php

namespace Tests\Feature;

use App\Models\Repartidor;
use App\Models\Usuario;
use App\Models\Vehiculo;
use App\Support\Revision;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Registro de repartidor: perfil, vehículo y lo que le falta subir. */
class RepartidorApiTest extends TestCase
{
    use DatabaseTransactions;

    private const MOTO = 1;

    private const BICICLETA = 2;

    private Usuario $cliente;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        $this->cliente = $this->crearUsuario();
        Sanctum::actingAs($this->cliente);
    }

    public function test_tipos_de_vehiculo_dicen_que_pide_cada_uno(): void
    {
        $tipos = $this->getJson('/api/tipos-vehiculo')->assertOk()->assertJsonCount(5)->collect()->keyBy('codigo');
        $pide = fn (string $tipo) => Arr::only($tipos[$tipo], ['requiere_placa', 'requiere_ruat', 'requiere_licencia']);

        $this->assertSame(['requiere_placa' => true, 'requiere_ruat' => true, 'requiere_licencia' => true], $pide('moto'));
        $this->assertSame(['requiere_placa' => false, 'requiere_ruat' => false, 'requiere_licencia' => false], $pide('bicicleta'));
        $this->assertSame('liviano', $tipos['moto']['categoria']['codigo']);
        $this->assertSame('grande', $tipos['camion']['categoria']['codigo']);
    }

    public function test_un_cliente_se_registra_como_repartidor_en_moto(): void
    {
        $this->postJson('/api/repartidor')
            ->assertCreated()
            ->assertJsonPath('estado_verificacion', 'pendiente')
            ->assertJsonPath('vehiculos', []);

        // Ya tiene la vista repartidor, en revisión.
        $this->getJson('/api/me')
            ->assertJsonPath('vistas', ['cliente', 'repartidor'])
            ->assertJsonPath('roles.repartidor.estado', 'pendiente');
        $this->getJson('/api/me/faltantes/repartidor')->assertJsonFragment(['codigo' => 'vehiculo', 'texto' => 'Registrar tu vehículo']);

        // La moto pide placa y RUAT.
        $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::MOTO])
            ->assertUnprocessable()
            ->assertJsonPath('errors.placa.0', 'Escribe la placa del vehículo.')
            ->assertJsonPath('errors.ruat.0', 'Escribe el número de RUAT del vehículo.');

        $vehiculo = $this->postJson('/api/vehiculos', [
            'tipo_vehiculo_id' => self::MOTO, 'placa' => ' 4321-xyz ', 'ruat' => 'R-778899',
            'marca' => 'Honda', 'modelo' => 'XR150', 'color' => 'Rojo', 'anio' => 2022,
        ])
            ->assertCreated()
            ->assertJsonPath('placa', '4321-XYZ')
            ->assertJsonPath('tipo.codigo', 'moto')
            ->assertJsonPath('estado_verificacion', 'pendiente')
            ->json('id');

        // Falta: carnet, selfie, licencia y las fotos de la moto, de la placa y del RUAT.
        $faltantes = $this->getJson('/api/me/faltantes/repartidor')->assertOk()->assertJsonPath('completo', false);
        $this->assertEqualsCanonicalizing([
            'documento.ci_anverso', 'documento.ci_reverso', 'documento.foto_rostro', 'documento.licencia_conducir',
            "documento.ruat:vehiculo$vehiculo", "documento.foto_vehiculo:vehiculo$vehiculo", "documento.foto_placa:vehiculo$vehiculo",
        ], $faltantes->json('faltantes.*.codigo'));
        $faltantes->assertJsonFragment(['codigo' => "documento.foto_placa:vehiculo$vehiculo", 'vehiculo_id' => $vehiculo]);

        // Sube todo lo que pide (las fotos del vehículo, con su vehiculo_id).
        foreach ($faltantes->json('faltantes') as $falta) {
            $this->post('/api/documentos', [
                'tipo' => $falta['documento'],
                'vehiculo_id' => $falta['vehiculo_id'],
                'archivo' => UploadedFile::fake()->image('foto.jpg'),
            ], ['Accept' => 'application/json'])
                ->assertCreated()
                ->assertJsonPath('vehiculo_id', $falta['vehiculo_id']);
        }

        $this->getJson('/api/me/faltantes/repartidor')->assertJsonPath('completo', true)->assertJsonPath('faltantes', []);
    }

    public function test_con_bicicleta_no_pide_placa_ruat_ni_licencia(): void
    {
        $this->postJson('/api/repartidor')->assertCreated();
        $vehiculo = $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::BICICLETA, 'color' => 'Azul'])
            ->assertCreated()
            ->assertJsonPath('placa', null)
            ->assertJsonPath('ruat', null)
            ->json('id');

        $this->assertEqualsCanonicalizing(
            ['documento.ci_anverso', 'documento.ci_reverso', 'documento.foto_rostro', "documento.foto_vehiculo:vehiculo$vehiculo"],
            $this->getJson('/api/me/faltantes/repartidor')->json('faltantes.*.codigo')
        );
    }

    public function test_no_se_registra_dos_veces_ni_se_repite_una_placa(): void
    {
        $this->postJson('/api/repartidor')->assertCreated();
        $this->postJson('/api/repartidor')
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Ya estás registrado como repartidor.');

        $moto = ['tipo_vehiculo_id' => self::MOTO, 'placa' => '9999-ABC', 'ruat' => '123'];
        $this->postJson('/api/vehiculos', $moto)->assertCreated();

        // Otra persona con la misma placa (aunque la escriba en minúsculas).
        Sanctum::actingAs($otro = $this->crearUsuario());
        $this->postJson('/api/repartidor')->assertCreated();
        $this->postJson('/api/vehiculos', [...$moto, 'placa' => '9999-abc'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.placa.0', 'Esa placa ya está registrada.');
        $this->assertSame(0, Vehiculo::where('repartidor_id', $otro->id)->count());
    }

    public function test_si_lo_rechazaron_puede_volver_a_solicitar(): void
    {
        $this->getJson('/api/repartidor')
            ->assertNotFound()
            ->assertJsonPath('message', 'Todavía no te registraste como repartidor.');

        $this->postJson('/api/repartidor')->assertCreated();
        $vehiculo = $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::BICICLETA])->assertCreated()->json('id');
        $repartidor = Repartidor::find($this->cliente->id);
        Revision::rechazarRepartidor($repartidor, 'La foto de la bici está borrosa');

        $this->getJson('/api/repartidor')
            ->assertOk()
            ->assertJsonPath('estado_verificacion', 'rechazado')
            ->assertJsonPath('motivo_rechazo', 'La foto de la bici está borrosa')
            ->assertJsonPath('vehiculos.0.estado_verificacion', 'rechazado');

        // Vuelve a enviar: él y su vehículo quedan otra vez en revisión.
        $this->postJson('/api/repartidor')
            ->assertOk()
            ->assertJsonPath('estado_verificacion', 'pendiente')
            ->assertJsonPath('motivo_rechazo', null)
            ->assertJsonPath('vehiculos.0.id', $vehiculo)
            ->assertJsonPath('vehiculos.0.estado_verificacion', 'pendiente');
        $this->getJson('/api/me')->assertJsonPath('vistas', ['cliente', 'repartidor']);

        // En cualquier otro estado sigue siendo "ya registrado".
        foreach (['pendiente', 'aprobado', 'suspendido'] as $estado) {
            $repartidor->forceFill(['estado_verificacion' => $estado])->save();
            $this->postJson('/api/repartidor')
                ->assertUnprocessable()
                ->assertJsonPath('message', 'Ya estás registrado como repartidor.');
        }
    }

    public function test_un_solo_vehiculo_en_uso(): void
    {
        $this->postJson('/api/repartidor')->assertCreated();
        $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::BICICLETA])->assertCreated();

        $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::MOTO, 'placa' => '5555-ZZZ', 'ruat' => '1'])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Ya tienes un vehículo registrado.');
        $this->assertSame(1, Vehiculo::where('repartidor_id', $this->cliente->id)->count());
    }

    public function test_nadie_registra_vehiculos_para_otra_persona(): void
    {
        // Sin ser repartidor no puede registrar un vehículo.
        $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::BICICLETA])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Primero regístrate como repartidor.');

        $duena = $this->crearUsuario();
        Sanctum::actingAs($duena);
        $this->postJson('/api/repartidor')->assertCreated();
        $ajeno = $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::BICICLETA])->assertCreated()->json('id');

        // Aunque mande el id de otra persona, el vehículo queda a su nombre.
        Sanctum::actingAs($this->cliente);
        $this->postJson('/api/repartidor')->assertCreated();
        $propio = $this->postJson('/api/vehiculos', ['tipo_vehiculo_id' => self::BICICLETA, 'repartidor_id' => $duena->id])
            ->assertCreated()->json('id');
        $this->assertSame($this->cliente->id, Vehiculo::find($propio)->repartidor_id);

        // Tampoco puede subir fotos al vehículo de otra persona (lo frena la base).
        $this->post('/api/documentos', [
            'tipo' => 'foto_vehiculo', 'vehiculo_id' => $ajeno, 'archivo' => UploadedFile::fake()->image('bici.jpg'),
        ], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Este documento debe ir ligado a un vehículo tuyo');
    }
}
