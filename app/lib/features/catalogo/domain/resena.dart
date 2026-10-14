import '../../../core/formato/formato.dart';

/// Reseña de un producto o negocio, como la muestra la API (autor: "Lucía R.").
class Resena {
  const Resena({
    required this.id,
    required this.tipo,
    required this.estrellas,
    required this.autor,
    this.comentario,
    this.productoId,
    this.productoNombre,
    this.respuesta,
    this.fecha,
  });

  final int id;

  /// 'producto' o 'negocio'
  final String tipo;
  final int estrellas;
  final String autor;
  final String? comentario;
  final int? productoId;
  final String? productoNombre;

  /// Respuesta del negocio (si contestó).
  final String? respuesta;
  final DateTime? fecha;

  factory Resena.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'] as Map?;
    return Resena(
      id: json['id'] as int,
      tipo: json['tipo'] as String,
      estrellas: (json['estrellas'] as num).toInt(),
      autor: (json['autor'] as String?) ?? 'Usuario',
      comentario: json['comentario'] as String?,
      productoId: (producto?['id'] as num?)?.toInt(),
      productoNombre: producto?['nombre'] as String?,
      respuesta: json['respuesta'] as String?,
      fecha: Formato.fechaDe(json['updated_at'] ?? json['created_at']),
    );
  }
}
