<?php

namespace App\Http\Requests\Concerns;

use App\Models\Categoria;

/**
 * Casillas "Vendo bebidas alcohólicas" y "Es una farmacia" al registrar o
 * editar un negocio. Ver App\Support\PermisosNegocio.
 */
trait PermisosDelNegocio
{
    protected function reglasPermisos(): array
    {
        return [
            // En multipart llegan como "1" / "0".
            'vende_alcohol' => ['sometimes', 'boolean'],
            'es_farmacia' => ['sometimes', 'boolean'],
        ];
    }

    /**
     * Datos validados listos para guardar en `negocio` (sin la foto). Si no
     * llegan las casillas (app antigua), no se cambian. El rubro "Bebidas
     * alcohólicas" (licorería) siempre vende alcohol.
     */
    public function datosNegocio(): array
    {
        $datos = collect($this->validated())->except('foto')->all();

        foreach (['vende_alcohol', 'es_farmacia'] as $casilla) {
            if ($this->has($casilla)) {
                $datos[$casilla] = $this->boolean($casilla);
            }
        }
        if (Categoria::whereKey($datos['categoria_id'])->value('permiso') === 'alcohol') {
            $datos['vende_alcohol'] = true;
        }

        return $datos;
    }
}
