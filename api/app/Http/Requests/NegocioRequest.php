<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Registrar un negocio: nombre, rubro, ubicación marcada en el mapa y foto.
 * NIT y razón social son opcionales (si no tiene NIT se usa el carnet del dueño).
 */
class NegocioRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:150'],
            // El rubro es una categoría principal (Alimentos, Tecnología…).
            'categoria_id' => ['required', 'integer', Rule::exists('categoria', 'id')->whereNull('categoria_padre_id')],
            'descripcion' => ['nullable', 'string', 'max:1000'],
            'telefono' => ['nullable', 'string', 'max:20'],
            'nit' => ['nullable', 'string', 'max:20', 'unique:negocio,nit'],
            'razon_social' => ['nullable', 'string', 'max:200'],
            'direccion' => ['required', 'string', 'max:255'],
            'referencia' => ['nullable', 'string', 'max:255'],
            'latitud' => ['required', 'numeric', 'between:-90,90'],
            'longitud' => ['required', 'numeric', 'between:-180,180'],
            'foto' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ];
    }

    public function attributes(): array
    {
        return [
            'nombre' => 'nombre del negocio',
            'categoria_id' => 'rubro',
            'nit' => 'NIT',
            'razon_social' => 'razón social',
            'latitud' => 'ubicación',
            'longitud' => 'ubicación',
            'foto' => 'foto del negocio',
        ];
    }

    public function messages(): array
    {
        return [
            'categoria_id.exists' => 'Elige un rubro de la lista.',
            'latitud.required' => 'Marca la ubicación del negocio en el mapa.',
            'longitud.required' => 'Marca la ubicación del negocio en el mapa.',
            'foto.required' => 'Agrega una foto del negocio.',
            'foto.max' => 'La foto no puede pesar más de 5 MB.',
        ];
    }
}
