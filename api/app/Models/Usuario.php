<?php

namespace App\Models;

use Filament\Auth\MultiFactor\App\Concerns\InteractsWithAppAuthentication;
use Filament\Auth\MultiFactor\App\Concerns\InteractsWithAppAuthenticationRecovery;
use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthentication;
use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthenticationRecovery;
use Filament\Models\Contracts\FilamentUser;
use Filament\Models\Contracts\HasName;
use Filament\Panel;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\HasApiTokens;

/**
 * Persona registrada. Todo usuario puede comprar (vista cliente); los roles
 * repartidor y comerciante son perfiles aparte (tablas repartidor y negocio).
 * Los que tienen es_admin = 1 entran al panel web (/admin), con verificación
 * en dos pasos (la clave del autenticador se guarda cifrada con APP_KEY).
 */
class Usuario extends Authenticatable implements FilamentUser, HasAppAuthentication, HasAppAuthenticationRecovery, HasName
{
    use HasApiTokens, InteractsWithAppAuthentication, InteractsWithAppAuthenticationRecovery, Notifiable, SoftDeletes;

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

    /** Perfil de repartidor (null si no se registró como tal). */
    public function repartidor(): HasOne
    {
        return $this->hasOne(Repartidor::class);
    }

    public function documentos(): HasMany
    {
        return $this->hasMany(Documento::class);
    }

    public function direcciones(): HasMany
    {
        return $this->hasMany(Direccion::class);
    }

    public function pedidos(): HasMany
    {
        return $this->hasMany(Pedido::class, 'comprador_id');
    }

    public function getNombreCompletoAttribute(): string
    {
        return trim($this->nombre.' '.$this->apellido);
    }

    /** Panel de administración: solo administradores con la cuenta activa. */
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->es_admin && $this->activo;
    }

    public function getFilamentName(): string
    {
        return $this->nombre_completo;
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
