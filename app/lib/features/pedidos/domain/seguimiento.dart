import '../../../core/formato/formato.dart';
import '../../../core/maps/coordenada.dart';
import 'pedido.dart';

/// Dónde va el pedido (`GET /api/pedidos/{id}/seguimiento`). La posición del
/// repartidor solo viene mientras lo lleva (aceptado o en camino).
class Seguimiento {
  const Seguimiento({
    required this.estado,
    required this.negocio,
    required this.destino,
    this.negocioNombre = '',
    this.repartidorNombre,
    this.vehiculo,
    this.placa,
    this.repartidor,
    this.haceSegundos,
    this.distanciaKm,
    this.tiempoMin,
  });

  final EstadoPedido estado;
  final String negocioNombre;
  final Coordenada negocio;
  final Coordenada destino;
  final String? repartidorNombre;
  final String? vehiculo;
  final String? placa;

  /// Última posición del repartidor (null si todavía no mandó o ya entregó).
  final Coordenada? repartidor;

  /// Hace cuántos segundos se actualizó la posición.
  final int? haceSegundos;

  /// Lo que falta recorrer y cuánto tarda (aprox.).
  final double? distanciaKm;
  final int? tiempoMin;

  factory Seguimiento.fromJson(Map<String, dynamic> json) {
    Coordenada punto(Map? m) => Coordenada(Formato.numero(m?['latitud']), Formato.numero(m?['longitud']));
    final rep = json['repartidor'] as Map?;
    final ubicacion = json['ubicacion_repartidor'] as Map?;
    return Seguimiento(
      estado: EstadoPedido.desde(json['estado'] as String?),
      negocioNombre: ((json['negocio'] as Map?)?['nombre'] as String?) ?? '',
      negocio: punto(json['negocio'] as Map?),
      destino: punto(json['destino'] as Map?),
      repartidorNombre: rep?['nombre'] as String?,
      vehiculo: rep?['vehiculo'] as String?,
      placa: rep?['placa'] as String?,
      repartidor: ubicacion == null ? null : punto(ubicacion),
      haceSegundos: (ubicacion?['hace_segundos'] as num?)?.toInt(),
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      tiempoMin: (json['tiempo_estimado_min'] as num?)?.toInt(),
    );
  }
}
