<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UsuarioResource;
use App\Models\TipoDocumento;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class PerfilController extends Controller
{
    /**
     * GET /api/me/faltantes/{rol} — qué le falta al usuario para usar un rol
     * (sale de sp_datos_faltantes). La app muestra solo eso, sin repetir lo
     * que ya llenó. Lista vacía = completo.
     */
    public function faltantes(Request $request, string $rol): JsonResponse
    {
        abort_unless(in_array($rol, ['cliente', 'repartidor', 'comerciante'], true), 404);

        $codigos = array_map(
            fn ($fila) => $fila->dato,
            DB::select('CALL sp_datos_faltantes(?, ?)', [$request->user()->id, $rol])
        );
        $nombresDocumento = TipoDocumento::pluck('nombre', 'codigo');

        $faltantes = array_map(fn (string $codigo) => $this->describir($codigo, $nombresDocumento), $codigos);

        return response()->json([
            'rol' => $rol,
            'completo' => $faltantes === [],
            'faltantes' => $faltantes,
        ]);
    }

    /** PUT /api/me — actualizar datos personales (ej. cuentas antiguas sin apellido o CI). */
    public function actualizar(Request $request): UsuarioResource
    {
        $usuario = $request->user();
        $complemento = (string) $request->input('ci_complemento', $usuario->ci_complemento ?? '');

        $datos = $request->validate([
            'nombre' => ['sometimes', 'required', 'string', 'max:100'],
            'apellido' => ['sometimes', 'required', 'string', 'max:100'],
            'telefono' => ['sometimes', 'nullable', 'string', 'max:20'],
            'ci_numero' => [
                'sometimes', 'required', 'string', 'max:20',
                Rule::unique('usuario', 'ci_numero')->where('ci_complemento', $complemento)->ignore($usuario->id),
            ],
            'ci_complemento' => ['sometimes', 'nullable', 'string', 'max:5'],
            'ci_expedido' => ['sometimes', 'nullable', Rule::in(['LP', 'CB', 'SC', 'OR', 'PT', 'CH', 'TJ', 'BE', 'PD'])],
        ], [], ['ci_numero' => 'número de carnet']);

        if (array_key_exists('ci_complemento', $datos)) {
            $datos['ci_complemento'] = (string) ($datos['ci_complemento'] ?? '');
        }
        $usuario->update($datos);

        return new UsuarioResource($usuario);
    }

    /**
     * Convierte el código de sp_datos_faltantes en algo que la app pueda
     * mostrar y resolver. Ej. "documento.ci_reverso" → "Foto del carnet de identidad (reverso)".
     */
    private function describir(string $codigo, $nombresDocumento): array
    {
        if (str_starts_with($codigo, 'documento.')) {
            [$tipo, $de] = array_pad(explode(':', substr($codigo, strlen('documento.')), 2), 2, null);

            return [
                'codigo' => $codigo,
                'tipo' => 'documento',
                'documento' => $tipo,
                'texto' => 'Foto: '.($nombresDocumento[$tipo] ?? $tipo),
                'vehiculo_id' => $de && str_starts_with($de, 'vehiculo') ? (int) substr($de, 8) : null,
                'negocio_id' => $de && str_starts_with($de, 'negocio') ? (int) substr($de, 7) : null,
            ];
        }

        [$base, $id] = array_pad(explode(':', $codigo, 2), 2, null);
        $texto = match ($base) {
            'apellido' => 'Tu apellido',
            'ci_numero' => 'Tu número de carnet',
            'vehiculo' => 'Registrar tu vehículo',
            'vehiculo.placa' => 'Número de placa del vehículo',
            'vehiculo.ruat' => 'Número de RUAT del vehículo',
            'negocio' => 'Registrar tu negocio',
            'negocio.ubicacion' => 'Ubicación de tu negocio en el mapa',
            'negocio.foto' => 'Foto de tu negocio',
            default => $codigo,
        };

        return [
            'codigo' => $codigo,
            'tipo' => 'dato',
            'documento' => null,
            'texto' => $texto,
            'vehiculo_id' => str_starts_with($base, 'vehiculo.') ? (int) $id : null,
            'negocio_id' => str_starts_with($base, 'negocio.') ? (int) $id : null,
        ];
    }
}
