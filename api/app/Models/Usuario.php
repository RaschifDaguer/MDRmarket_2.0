<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\HasApiTokens;

/**
 * Persona registrada. Todo usuario puede comprar (vista cliente); los roles
 * repartidor y comerciante son perfiles aparte (tablas repartidor y negocio).
 */
class Usuario extends Authenticatable
{
    use HasApiTokens, Notifiable, SoftDeletes;

    protected $table = 'usuario';

    protected $fillable = [
        'nombre',
        'apellido',
        'email',
        'password',
        'telefono',
        'ci_numero',
        'ci_complemento',
        'ci_expedido',
        'fecha_nacimiento',
        'foto_perfil_url',
        'rol_activo',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'fecha_nacimiento' => 'date',
            'password' => 'hashed',
            'es_admin' => 'boolean',
            'activo' => 'boolean',
        ];
    }

    public function negocios(): HasMany
    {
        return $this->hasMany(Negocio::class);
    }

    /** ¿Tiene una suspensión o bloqueo vigente para ese rol? ('todos' = cuenta entera). */
    public function tieneSancion(string $rol): bool
    {
        return (bool) DB::scalar('SELECT fn_sancion_activa(?, ?)', [$this->id, $rol]);
    }

    /** Qué perfiles tiene y si está sancionado en alguno (vista v_usuario_roles). */
    public function roles(): object
    {
        return DB::table('v_usuario_roles')->where('usuario_id', $this->id)->first();
    }

    /**
     * Vistas que puede abrir en la app. Cliente siempre; repartidor si se
     * registró como tal (aunque esté en revisión, para que vea su estado);
     * comerciante si tiene al menos un negocio.
     */
    public function vistas(?object $roles = null): array
    {
        $roles ??= $this->roles();

        $vistas = ['cliente'];
        if ($roles->es_repartidor && $roles->estado_repartidor !== 'rechazado') {
            $vistas[] = 'repartidor';
        }
        if ($roles->total_negocios > 0) {
            $vistas[] = 'comerciante';
        }

        return $vistas;
    }
}
