<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Datos del usuario que recibe la app, con las vistas que puede usar. */
class UsuarioResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $roles = $this->roles();
        $vistas = $this->vistas($roles);

        return [
            'id' => $this->id,
            'nombre' => $this->nombre,
            'apellido' => $this->apellido,
            'email' => $this->email,
            'telefono' => $this->telefono,
            'ci_numero' => $this->ci_numero,
            'ci_complemento' => $this->ci_complemento,
            'ci_expedido' => $this->ci_expedido,
            'foto_perfil_url' => $this->foto_perfil_url,
            'rol_activo' => $this->rol_activo,
            'es_admin' => (bool) $this->es_admin,
            'vistas' => $vistas,
            // El botón "cambiar vista" solo se muestra si tiene más de una.
            'puede_cambiar_vista' => count($vistas) > 1,
            // Para el botón "cambiar a vista…": qué perfiles tiene y en qué estado.
            'roles' => [
                'cliente' => ['activo' => ! $roles->sancionado_cliente],
                'repartidor' => $roles->es_repartidor
                    ? ['estado' => $roles->estado_repartidor, 'sancionado' => (bool) $roles->sancionado_repartidor]
                    : null,
                'comerciante' => $roles->total_negocios > 0
                    ? ['negocios' => (int) $roles->total_negocios, 'sancionado' => (bool) $roles->sancionado_comerciante]
                    : null,
            ],
        ];
    }
}
