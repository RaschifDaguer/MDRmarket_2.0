<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Crear o editar un producto (multipart, por la foto). Siempre llega el
 * formulario completo. Sin `controlar_stock`, el producto no lleva stock
 * (ej. comida hecha al momento).
 */
class ProductoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        // En multipart los vacíos llegan como "": se toman como "sin valor".
        $this->merge(collect(['costo', 'precio_oferta', 'oferta_inicio', 'oferta_fin', 'stock', 'descripcion'])
            ->filter(fn ($campo) => $this->input($campo) === '')
            ->mapWithKeys(fn ($campo) => [$campo => null])
            ->all());
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:150'],
            // Siempre una subcategoría (ej. "Farmacia y medicamentos", no "Salud y Belleza").
            'categoria_id' => ['required', 'integer', Rule::exists('categoria', 'id')->whereNotNull('categoria_padre_id')],
            'descripcion' => ['nullable', 'string', 'max:2000'],
            'precio' => ['required', 'numeric', 'min:0.5', 'max:999999'],
            'costo' => ['nullable', 'numeric', 'min:0', 'max:999999'],
            'precio_oferta' => ['nullable', 'numeric', 'min:0', 'lt:precio'],
            'oferta_inicio' => ['nullable', 'date'],
            'oferta_fin' => ['nullable', 'date', 'after:now', ...($this->filled('oferta_inicio') ? ['after:oferta_inicio'] : [])],
            'controlar_stock' => ['sometimes', 'boolean'],
            'stock' => ['nullable', 'required_if_accepted:controlar_stock', 'integer', 'min:0', 'max:100000'],
            'disponible' => ['sometimes', 'boolean'],
            // Vehículo mínimo para llevarlo: 1 liviano (moto), 2 mediano (auto), 3 grande (camión).
            'categoria_vehiculo_id' => ['nullable', 'integer', 'in:1,2,3'],
            'foto' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ];
    }

    public function attributes(): array
    {
        return [
            'nombre' => 'nombre del producto',
            'categoria_id' => 'categoría',
            'precio' => 'precio',
            'costo' => 'costo',
            'precio_oferta' => 'precio de oferta',
            'oferta_inicio' => 'inicio de la oferta',
            'oferta_fin' => 'fin de la oferta',
            'categoria_vehiculo_id' => 'tamaño',
        ];
    }

    public function messages(): array
    {
        return [
            'categoria_id.exists' => 'Elige una categoría de la lista.',
            'precio_oferta.lt' => 'El precio de oferta tiene que ser menor al precio normal.',
            'oferta_fin.after' => 'La oferta tiene que terminar después de empezar (y en el futuro).',
            'stock.required_if_accepted' => 'Escribe cuántos tienes, o desactiva "Controlar stock".',
            'foto.max' => 'La foto no puede pesar más de 5 MB.',
        ];
    }

    /** Datos listos para guardar en `producto`. */
    public function datosProducto(): array
    {
        $datos = $this->safe()->except(['foto', 'controlar_stock']);
        if (! $this->boolean('controlar_stock')) {
            $datos['stock'] = null;
        }
        $datos['categoria_vehiculo_id'] ??= 1;
        $datos['disponible'] = $this->boolean('disponible', true);

        return $datos;
    }
}
