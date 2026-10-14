<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Pedido de un comprador a un negocio. `total` lo calcula la base
 * (subtotal + envío + servicio - descuento). Flujo de estados:
 * pendiente → confirmado → preparando → listo → en_camino → entregado
 * (o cancelado / rechazado). Al pasar a "entregado", trg_pedido_au registra
 * la venta en registro_comercio; al cancelar o rechazar, devuelve el stock.
 */
class Pedido extends Model
{
    protected $table = 'pedido';

    public const ESTADOS_ACTIVOS = ['pendiente', 'confirmado', 'preparando', 'listo', 'en_camino'];

    protected $fillable = [
        'comprador_id',
        'negocio_id',
        'direccion_id',
        'direccion_entrega',
        'referencia_entrega',
        'latitud_entrega',
        'longitud_entrega',
        'notas',
        'categoria_vehiculo_requerida_id',
        'estado',
        'subtotal',
        'costo_envio',
        'tarifa_servicio',
        'descuento',
        'comision_plataforma',
        'metodo_pago',
        'estado_pago',
        'codigo_entrega',
        'distancia_km',
        'tiempo_estimado_min',
        'confirmado_en',
        'recogido_en',
        'entregado_en',
        'cancelado_en',
        'cancelado_por',
        'motivo_cancelacion',
        'pagado_en',
    ];

    protected function casts(): array
    {
        return [
            'latitud_entrega' => 'float',
            'longitud_entrega' => 'float',
            'subtotal' => 'decimal:2',
            'costo_envio' => 'decimal:2',
            'tarifa_servicio' => 'decimal:2',
            'descuento' => 'decimal:2',
            'total' => 'decimal:2',
            'comision_plataforma' => 'decimal:2',
            'distancia_km' => 'float',
            'confirmado_en' => 'datetime',
            'asignado_en' => 'datetime',
            'recogido_en' => 'datetime',
            'entregado_en' => 'datetime',
            'cancelado_en' => 'datetime',
            'pagado_en' => 'datetime',
        ];
    }

    public function comprador(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'comprador_id');
    }

    public function negocio(): BelongsTo
    {
        return $this->belongsTo(Negocio::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(PedidoItem::class);
    }

    public function historial(): HasMany
    {
        return $this->hasMany(PedidoEstadoHistorial::class)->orderBy('id');
    }

    /** Guarda el cambio de estado en el historial (quién y con qué rol). */
    public function registrarEstado(?string $anterior, string $nuevo, ?int $usuarioId, string $rol, ?string $motivo = null): void
    {
        $this->historial()->create([
            'estado_anterior' => $anterior,
            'estado_nuevo' => $nuevo,
            'usuario_id' => $usuarioId,
            'rol' => $rol,
            'motivo' => $motivo,
        ]);
    }
}
