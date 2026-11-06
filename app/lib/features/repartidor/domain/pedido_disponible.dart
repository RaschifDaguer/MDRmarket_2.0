import '../../../core/formato/formato.dart';
import '../../pedidos/domain/pedido.dart';

/// Pedido "listo" que el repartidor puede aceptar (`GET /api/repartidor/pedidos-disponibles`).
/// No trae datos del cliente: los recibe recién al aceptarlo.
class PedidoDisponible {
  const PedidoDisponible({
    required this.id,
    required this.negocioNombre,
    required this.direccionEntrega,
    required this.costoEnvio,
    required this.total,
    this.negocioDireccion,
    this.negocioLogo,
    this.distanciaKm,
    this.distanciaAlNegocioKm,
    this.metodoPago = 'efectivo',
    this.tamano,
    this.totalItems,
    this.propio = false,
  });

  final int id;
  final String negocioNombre;
  final String? negocioDireccion;
  final String? negocioLogo;
  final String direccionEntrega;

  /// Del negocio a la casa del cliente.
  final double? distanciaKm;

  /// De donde está el repartidor al negocio (null si no mandó su GPS).
  final double? distanciaAlNegocioKm;

  /// Lo que gana el repartidor por llevarlo.
  final double costoEnvio;
  final double total;
  final String metodoPago;

  /// Liviano, Mediano o Grande.
  final String? tamano;
  final int? totalItems;

  /// Su propia compra (o de su negocio): no lo puede llevar él, lo lleva otro repartidor.
  final bool propio;

  factory PedidoDisponible.fromJson(Map<String, dynamic> json) {
    final negocio = (json['negocio'] as Map?) ?? const {};
    return PedidoDisponible(
      id: json['id'] as int,
      negocioNombre: (negocio['nombre'] as String?) ?? '',
      negocioDireccion: negocio['direccion'] as String?,
      negocioLogo: negocio['logo_url'] as String?,
      direccionEntrega: (json['direccion_entrega'] as String?) ?? '',
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      distanciaAlNegocioKm: (json['distancia_al_negocio_km'] as num?)?.toDouble(),
      costoEnvio: Formato.numero(json['costo_envio']),
      total: Formato.numero(json['total']),
      metodoPago: (json['metodo_pago'] as String?) ?? 'efectivo',
      tamano: json['tamano'] as String?,
      totalItems: (json['total_items'] as num?)?.toInt(),
      propio: json['propio'] == true,
    );
  }
}

/// Historial de entregas con su resumen (`GET /api/repartidor/entregas`).
class Entregas {
  const Entregas({required this.pedidos, this.total = 0, this.totalEnvios = 0});

  final List<Pedido> pedidos;
  final int total;
  final double totalEnvios;
}
