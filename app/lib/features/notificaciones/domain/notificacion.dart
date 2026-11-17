import '../../../core/formato/formato.dart';

/// Un aviso para el usuario.
class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.cuerpo,
    this.pedidoId,
    this.leida = false,
    this.fecha,
  });

  final int id;

  /// pedido_nuevo, pedido_en_camino, pedido_entregado, reporte_resuelto…
  final String tipo;
  final String titulo;
  final String? cuerpo;
  final int? pedidoId;
  final bool leida;
  final DateTime? fecha;

  Notificacion leidaYa() =>
      Notificacion(id: id, tipo: tipo, titulo: titulo, cuerpo: cuerpo, pedidoId: pedidoId, leida: true, fecha: fecha);

  factory Notificacion.fromJson(Map<String, dynamic> json) => Notificacion(
    id: json['id'] as int,
    tipo: (json['tipo'] as String?) ?? '',
    titulo: json['titulo'] as String,
    cuerpo: json['cuerpo'] as String?,
    pedidoId: (json['pedido_id'] as num?)?.toInt(),
    leida: json['leida'] == true,
    fecha: Formato.fechaDe(json['created_at']),
  );
}
