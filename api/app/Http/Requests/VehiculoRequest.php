<?php

namespace App\Http\Requests;

use App\Models\TipoVehiculo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Registrar el vehículo del repartidor. Placa y RUAT son obligatorios solo si
 * el tipo los pide (la bicicleta no). La placa no se puede repetir.
 */
class VehiculoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** La placa se guarda en mayúsculas ("scz-1234" y "SCZ-1234" son la misma). */
    protected function prepareForValidation(): void
    {
        foreach (['placa', 'ruat'] as $campo) {
            if (is_string($this->input($campo))) {
                $this->merge([$campo => mb_strtoupper(trim($this->input($campo)))]);
            }
        }
    }

    public function rules(): array
    {
        $tipo = TipoVehiculo::find($this->integer('tipo_vehiculo_id'));

        return [
            'tipo_vehiculo_id' => ['required', 'integer', Rule::exists('tipo_vehiculo', 'id')],
            // La base no deja repetir la placa (ni de vehículos dados de baja).
            'placa' => [$tipo?->requiere_placa ? 'required' : 'nullable', 'string', 'max:15', Rule::unique('vehiculo', 'placa')],
            'ruat' => [$tipo?->requiere_ruat ? 'required' : 'nullable', 'string', 'max:30'],
            'marca' => ['nullable', 'string', 'max:50'],
            'modelo' => ['nullable', 'string', 'max:50'],
            'color' => ['nullable', 'string', 'max:30'],
            'anio' => ['nullable', 'integer', 'between:1950,'.(now()->year + 1)],
        ];
    }

    public function attributes(): array
    {
        return [
            'tipo_vehiculo_id' => 'tipo de vehículo',
            'placa' => 'placa',
            'ruat' => 'RUAT',
            'anio' => 'año',
        ];
    }

    public function messages(): array
    {
        return [
            'tipo_vehiculo_id.required' => 'Elige el tipo de vehículo.',
            'tipo_vehiculo_id.exists' => 'Elige un tipo de vehículo de la lista.',
            'placa.required' => 'Escribe la placa del vehículo.',
            'placa.unique' => 'Esa placa ya está registrada.',
            'ruat.required' => 'Escribe el número de RUAT del vehículo.',
        ];
    }
}
