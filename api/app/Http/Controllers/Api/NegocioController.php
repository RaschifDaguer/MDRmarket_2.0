<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\NegocioRequest;
use App\Http\Resources\NegocioResource;
use App\Models\Negocio;
use App\Support\Archivos;
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
            $request->user()->negocios()->with('categoria')->latest('id')->get()
        );
    }

    /**
     * POST /api/negocios — registra un negocio (multipart, con la foto).
     * Queda "pendiente" hasta que un administrador lo apruebe. Al tener un
     * negocio, el usuario ya puede cambiar a la vista comerciante.
     */
    public function store(NegocioRequest $request): JsonResponse
    {
        $datos = $request->validated();

        // Solo se atiende del centro hasta el 10mo anillo de Santa Cruz.
        $anillo = DB::scalar('SELECT fn_anillo(?, ?)', [$datos['latitud'], $datos['longitud']]);
        if ($anillo === null) {
            throw ValidationException::withMessages([
                'latitud' => 'La ubicación está fuera de la zona de cobertura (del centro al 10mo anillo).',
            ]);
        }

        $negocio = $request->user()->negocios()->create([
            ...collect($datos)->except('foto')->all(),
            'logo_url' => Archivos::guardarPublico($request->file('foto'), 'negocios'),
        ]);

        // refresh() trae los valores que pone la base (estado "pendiente", abierto…).
        return (new NegocioResource($negocio->refresh()->load('categoria')))
            ->response()
            ->setStatusCode(201);
    }
}
