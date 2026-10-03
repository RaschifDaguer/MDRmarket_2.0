<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\RegistroRequest;
use App\Http\Resources\UsuarioResource;
use App\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /** POST /api/auth/registro — crea la cuenta (vista cliente) y devuelve el token. */
    public function registro(RegistroRequest $request): JsonResponse
    {
        $datos = $request->validated();

        $usuario = Usuario::create([
            ...collect($datos)->except(['dispositivo', 'password_confirmation'])->all(),
            'ci_complemento' => $datos['ci_complemento'] ?? '',
            'rol_activo' => 'cliente',
        ]);

        return $this->respuestaConToken($usuario, $datos['dispositivo'] ?? null, 201);
    }

    /** POST /api/auth/login */
    public function login(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'dispositivo' => ['nullable', 'string', 'max:100'],
        ]);

        $usuario = Usuario::where('email', $datos['email'])->first();

        if (! $usuario || ! Hash::check($datos['password'], $usuario->password)) {
            throw ValidationException::withMessages(['email' => 'Correo o contraseña incorrectos.']);
        }
        if (! $usuario->activo) {
            return response()->json(['message' => 'Tu cuenta está desactivada.'], 403);
        }
        if ($usuario->tieneSancion('todos')) {
            return response()->json(['message' => 'Tu cuenta está bloqueada por una sanción.'], 403);
        }

        return $this->respuestaConToken($usuario, $datos['dispositivo'] ?? null);
    }

    /** POST /api/auth/logout — cierra la sesión de este dispositivo. */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Sesión cerrada.']);
    }

    /** GET /api/me — datos del usuario conectado. */
    public function me(Request $request): UsuarioResource
    {
        return new UsuarioResource($request->user());
    }

    /** PUT /api/me/vista — guarda la vista elegida con el botón "cambiar vista". */
    public function cambiarVista(Request $request): UsuarioResource
    {
        $usuario = $request->user();
        $datos = $request->validate([
            'vista' => ['required', Rule::in($usuario->vistas())],
        ], [
            'vista.in' => 'No tienes acceso a esa vista.',
        ]);

        $usuario->update(['rol_activo' => $datos['vista']]);

        return new UsuarioResource($usuario);
    }

    private function respuestaConToken(Usuario $usuario, ?string $dispositivo, int $status = 200): JsonResponse
    {
        $token = $usuario->createToken($dispositivo ?: 'app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'usuario' => new UsuarioResource($usuario),
        ], $status);
    }
}
