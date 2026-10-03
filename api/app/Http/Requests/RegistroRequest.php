<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/** Registro de cuenta: correo, contraseña, nombre, apellido y carnet. */
class RegistroRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:100'],
            'apellido' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:191', 'unique:usuario,email'],
            // Se escribe dos veces (password + password_confirmation) y deben
            // coincidir. Mínimo 8 caracteres con mayúscula, minúscula y número.
            'password' => ['required', 'string', 'confirmed', Password::min(8)->mixedCase()->numbers()],
            'ci_numero' => [
                'required', 'string', 'max:20',
                // El mismo número con el mismo complemento no puede repetirse.
                Rule::unique('usuario', 'ci_numero')
                    ->where('ci_complemento', (string) $this->input('ci_complemento', '')),
            ],
            'ci_complemento' => ['nullable', 'string', 'max:5'],
            'ci_expedido' => ['nullable', Rule::in(['LP', 'CB', 'SC', 'OR', 'PT', 'CH', 'TJ', 'BE', 'PD'])],
            'telefono' => ['nullable', 'string', 'max:20'],
            'dispositivo' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function attributes(): array
    {
        return [
            'ci_numero' => 'número de carnet',
            'ci_complemento' => 'complemento del carnet',
            'ci_expedido' => 'lugar de expedición',
        ];
    }
}
