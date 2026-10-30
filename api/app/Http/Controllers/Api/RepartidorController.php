<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\VehiculoRequest;
use App\Models\Repartidor;
use App\Models\TipoVehiculo;
use App\Models\Vehiculo;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class RepartidorController extends Controller
{
    /**
     * GET /api/tipos-vehiculo — moto, bicicleta, auto… con su categoría
     * (liviano, mediano, grande) y qué pide cada uno (placa, RUAT, licencia).
     */
    public function tiposVehiculo(): JsonResponse
    {
        $tipos = TipoVehiculo::with('categoria')->orderBy('categoria_vehiculo_id')->orderBy('id')->get();

        return response()->json($tipos->map(fn (TipoVehiculo $t) => [
            'id' => $t->id,
            'codigo' => $t->codigo,
            'nombre' => $t->nombre,
            'requiere_placa' => $t->requiere_placa,
            'requiere_ruat' => $t->requiere_ruat,
            'requiere_licencia' => $t->requiere_licencia,
            'categoria' => [
                'id' => $t->categoria->id,
                'codigo' => $t->categoria->codigo,
                'nombre' => $t->categoria->nombre,
                'descripcion' => $t->categoria->descripcion,
                'capacidad_kg_max' => $t->categoria->capacidad_kg_max,
            ],
        ]));
    }

    /**
     * POST /api/repartidor — el usuario se registra como repartidor. Queda
     * "pendiente" hasta que un administrador lo apruebe; mientras tanto ya
     * tiene la vista repartidor (para ver su estado y lo que le falta).
     */
    public function store(Request $request): JsonResponse
    {
        $usuario = $request->user();
        if ($usuario->repartidor()->exists()) {
            return $this->yaRegistrado();
        }

        try {
            $repartidor = $usuario->repartidor()->create();
        } catch (UniqueConstraintViolationException) {
            return $this->yaRegistrado(); // dos solicitudes a la vez
        }

        // refresh() trae los valores que pone la base (estado "pendiente"…).
        return response()->json($this->formato($repartidor->refresh()->load('vehiculos.tipo')), 201);
    }

    /**
     * POST /api/vehiculos — registra el vehículo del repartidor conectado
     * (siempre a su nombre). Después se suben sus fotos con
     * POST /api/documentos y el vehiculo_id que devuelve.
     */
    public function vehiculo(VehiculoRequest $request): JsonResponse
    {
        $repartidor = $request->user()->repartidor()->first();
        if (! $repartidor) {
            return response()->json(['message' => 'Primero regístrate como repartidor.'], 422);
        }

        try {
            $vehiculo = $repartidor->vehiculos()->create($request->validated());
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['placa' => 'Esa placa ya está registrada.']);
        }

        return response()->json($this->formatoVehiculo($vehiculo->refresh()->load('tipo')), 201);
    }

    private function yaRegistrado(): JsonResponse
    {
        return response()->json(['message' => 'Ya estás registrado como repartidor.'], 422);
    }

    private function formato(Repartidor $r): array
    {
        return [
            'usuario_id' => $r->usuario_id,
            'estado_verificacion' => $r->estado_verificacion,
            'disponible' => $r->disponible,
            'rating_promedio' => $r->rating_promedio,
            'total_entregas' => $r->total_entregas,
            'vehiculos' => $r->vehiculos->map(fn (Vehiculo $v) => $this->formatoVehiculo($v))->all(),
            'created_at' => $r->created_at,
        ];
    }

    private function formatoVehiculo(Vehiculo $v): array
    {
        return [
            'id' => $v->id,
            'tipo' => ['id' => $v->tipo->id, 'codigo' => $v->tipo->codigo, 'nombre' => $v->tipo->nombre],
            'placa' => $v->placa,
            'ruat' => $v->ruat,
            'marca' => $v->marca,
            'modelo' => $v->modelo,
            'color' => $v->color,
            'anio' => $v->anio,
            'en_uso' => $v->en_uso,
            'estado_verificacion' => $v->estado_verificacion,
            'created_at' => $v->created_at,
        ];
    }
}
