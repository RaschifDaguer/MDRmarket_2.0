<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Documento;
use App\Models\TipoDocumento;
use App\Support\Archivos;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class DocumentoController extends Controller
{
    /** GET /api/documentos — documentos que subió el usuario y su estado de revisión. */
    public function index(Request $request): JsonResponse
    {
        $documentos = Documento::with('tipo')
            ->where('usuario_id', $request->user()->id)
            ->latest('id')
            ->get();

        return response()->json($documentos->map(fn (Documento $d) => $this->formato($d)));
    }

    /**
     * POST /api/documentos — sube la foto de un documento (multipart).
     * Se guarda en el disco privado. Si ya había uno igual en revisión, se
     * reemplaza la foto en vez de crear otro.
     */
    public function store(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'tipo' => ['required', Rule::exists('tipo_documento', 'codigo')->where('activo', 1)],
            'archivo' => ['required', 'file', 'mimes:jpg,jpeg,png,webp,pdf', 'max:5120'],
            'negocio_id' => ['nullable', 'integer'],
            'vehiculo_id' => ['nullable', 'integer'],
            'numero' => ['nullable', 'string', 'max:50'],
        ], [
            'archivo.required' => 'Agrega la foto del documento.',
            'archivo.max' => 'El archivo no puede pesar más de 5 MB.',
        ]);

        $usuario = $request->user();
        $tipo = TipoDocumento::where('codigo', $datos['tipo'])->firstOrFail();
        $claves = [
            'usuario_id' => $usuario->id,
            'tipo_documento_id' => $tipo->id,
            'negocio_id' => $datos['negocio_id'] ?? null,
            'vehiculo_id' => $datos['vehiculo_id'] ?? null,
        ];

        $ruta = Archivos::guardarPrivado($request->file('archivo'), "documentos/{$usuario->id}");

        try {
            $existente = Documento::where($claves)->where('estado', 'pendiente')->first();
            if ($existente) {
                Archivos::borrarPrivado($existente->archivo_url);
                $existente->update(['archivo_url' => $ruta, 'numero' => $datos['numero'] ?? $existente->numero]);
                $documento = $existente;
            } else {
                // El trigger trg_documento_bi rechaza vehículos o negocios ajenos.
                $documento = Documento::create([...$claves, 'archivo_url' => $ruta, 'numero' => $datos['numero'] ?? null]);
            }
        } catch (QueryException $e) {
            Archivos::borrarPrivado($ruta);
            throw $e;
        }

        return response()->json($this->formato($documento->refresh()->load('tipo')), 201);
    }

    private function formato(Documento $d): array
    {
        return [
            'id' => $d->id,
            'tipo' => $d->tipo->codigo,
            'nombre' => $d->tipo->nombre,
            'estado' => $d->estado,
            'observacion' => $d->observacion,
            'negocio_id' => $d->negocio_id,
            'vehiculo_id' => $d->vehiculo_id,
            'created_at' => $d->created_at,
        ];
    }
}
