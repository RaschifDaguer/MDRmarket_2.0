<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\NegocioPerfilRequest;
use App\Http\Requests\NegocioRequest;
use App\Http\Resources\NegocioResource;
use App\Models\Categoria;
use App\Models\Negocio;
use App\Support\Archivos;
use App\Support\Envio;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class NegocioController extends Controller
{
    /** GET /api/negocios — los negocios del usuario conectado. */
    public function index(Request $request): AnonymousResourceCollection
    {
        return NegocioResource::collection(
            $request->user()->negocios()->with(['categoria', 'horarios'])->latest('id')->get()
        );
    }

    /**
     * POST /api/negocios — registra un negocio (multipart, con la foto).
     * Queda "pendiente" hasta que un administrador lo apruebe. Al tener un
     * negocio, el usuario ya puede cambiar a la vista comerciante.
     */
    public function store(NegocioRequest $request): JsonResponse
    {
        // Con las casillas de licorería y farmacia (ver PermisosDelNegocio).
        $datos = $request->datosNegocio();

        // Solo se atiende del centro hasta el 10mo anillo de Santa Cruz.
        Envio::exigirCobertura((float) $datos['latitud'], (float) $datos['longitud']);

        $negocio = $request->user()->negocios()->create([
            ...$datos,
            'logo_url' => Archivos::guardarPublico($request->file('foto'), 'negocios'),
        ]);

        // refresh() trae los valores que pone la base (estado "pendiente", abierto…).
        return (new NegocioResource($negocio->refresh()->load('categoria')))
            ->response()
            ->setStatusCode(201);
    }

    /** POST /api/negocios/{negocio} — editar el perfil (multipart; la foto es opcional). */
    public function update(NegocioPerfilRequest $request, Negocio $negocio): NegocioResource
    {
        $datos = $request->datosNegocio();
        Envio::exigirCobertura((float) $datos['latitud'], (float) $datos['longitud']);
        $this->exigirSinProductosDelPermiso($negocio, $datos);

        if ($request->hasFile('foto')) {
            $anterior = $negocio->logo_url;
            $datos['logo_url'] = Archivos::guardarPublico($request->file('foto'), 'negocios');
            Archivos::borrarPublico($anterior);
        }
        $datos['pedido_minimo'] ??= 0;
        $negocio->update($datos);

        return new NegocioResource($negocio->refresh()->load(['categoria', 'horarios']));
    }

    /** PATCH /api/negocios/{negocio}/abierto — abrir o cerrar ahora (no recibe pedidos si está cerrado). */
    public function abierto(Request $request, Negocio $negocio): NegocioResource
    {
        $negocio->update($request->validate(['abierto' => ['required', 'boolean']]));

        return new NegocioResource($negocio->refresh()->load(['categoria', 'horarios']));
    }

    /**
     * PUT /api/negocios/{negocio}/horario — reemplaza el horario completo.
     * horarios: [{dia_semana: 1..7 (1 = lunes), hora_apertura: "08:00", hora_cierre: "20:00"}]
     */
    public function horario(Request $request, Negocio $negocio): NegocioResource
    {
        $datos = $request->validate([
            'horarios' => ['present', 'array', 'max:21'],
            'horarios.*.dia_semana' => ['required', 'integer', 'between:1,7'],
            'horarios.*.hora_apertura' => ['required', 'date_format:H:i'],
            'horarios.*.hora_cierre' => ['required', 'date_format:H:i'],
        ]);

        foreach ($datos['horarios'] as $i => $tramo) {
            if ($tramo['hora_cierre'] <= $tramo['hora_apertura']) {
                throw ValidationException::withMessages(["horarios.$i.hora_cierre" => 'La hora de cierre tiene que ser después de la de apertura.']);
            }
        }

        DB::transaction(function () use ($negocio, $datos) {
            $negocio->horarios()->delete();
            // Sin repetir el mismo día y hora de apertura.
            collect($datos['horarios'])->unique(fn ($t) => $t['dia_semana'].$t['hora_apertura'])
                ->each(fn ($t) => $negocio->horarios()->create($t));
        });

        return new NegocioResource($negocio->refresh()->load(['categoria', 'horarios']));
    }

    /**
     * Quitar "Vendo bebidas alcohólicas" o "Es una farmacia" solo si ya no
     * tiene productos de esas categorías (si no, seguiría vendiéndolos sin permiso).
     */
    private function exigirSinProductosDelPermiso(Negocio $negocio, array $datos): void
    {
        $quita = [
            'alcohol' => $negocio->vende_alcohol && array_key_exists('vende_alcohol', $datos) && ! $datos['vende_alcohol'],
            'farmacia' => $negocio->es_farmacia && array_key_exists('es_farmacia', $datos) && ! $datos['es_farmacia'],
        ];

        foreach (array_keys(array_filter($quita)) as $permiso) {
            $categorias = Categoria::where('permiso', $permiso)->pluck('id');
            if ($negocio->productos()->whereIn('categoria_id', $categorias)->exists()) {
                throw ValidationException::withMessages([
                    $permiso === 'alcohol' ? 'vende_alcohol' : 'es_farmacia' => $permiso === 'alcohol'
                        ? 'Primero elimina tus bebidas alcohólicas (o cámbialas de categoría).'
                        : 'Primero elimina tus medicamentos (o cámbialos de categoría).',
                ]);
            }
        }
    }
}
