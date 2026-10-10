<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Editar el perfil del negocio (multipart). La foto es opcional: si no llega,
 * se mantiene la anterior.
 */
class NegocioPerfilRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge(collect(['descripcion', 'telefono', 'referencia', 'nit', 'razon_social', 'tiempo_preparacion_min', 'pedido_minimo'])
            ->filter(fn ($campo) => $this->input($campo) === '')
            ->mapWithKeys(fn ($campo) => [$campo => null])
            ->all());
    }

    public function rules(): array
    {
        $negocio = $this->route('negocio');

        return [
            'nombre' => ['required', 'string', 'max:150'],
            'categoria_id' => ['required', 'integer', Rule::exists('categoria', 'id')->whereNull('categoria_padre_id')],
            'descripcion' => ['nullable', 'string', 'max:1000'],
            'telefono' => ['nullable', 'string', 'max:20'],
            'nit' => ['nullable', 'string', 'max:20', Rule::unique('negocio', 'nit')->ignore($negocio?->id)],
            'razon_social' => ['nullable', 'string', 'max:200'],
            'direccion' => ['required', 'string', 'max:255'],
            'referencia' => ['nullable', 'string', 'max:255'],
            'latitud' => ['required', 'numeric', 'between:-90,90'],
            'longitud' => ['required', 'numeric', 'between:-180,180'],
            'tiempo_preparacion_min' => ['nullable', 'integer', 'min:1', 'max:600'],
            'pedido_minimo' => ['nullable', 'numeric', 'min:0', 'max:100000'],
            'foto' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ];
    }

    public function attributes(): array
    {
        return [
            'nombre' => 'nombre del negocio',
            'categoria_id' => 'rubro',
            'nit' => 'NIT',
            'razon_social' => 'nombre para facturas',
            'latitud' => 'ubicación',
            'longitud' => 'ubicación',
            'tiempo_preparacion_min' => 'tiempo de preparación',
            'pedido_minimo' => 'pedido mínimo',
            'foto' => 'foto del negocio',
        ];
    }

    public function messages(): array
    {
        return [
            'categoria_id.exists' => 'Elige un rubro de la lista.',
            'foto.max' => 'La foto no puede pesar más de 5 MB.',
        ];
    }
}
