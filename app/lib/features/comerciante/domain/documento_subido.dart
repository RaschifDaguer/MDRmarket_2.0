/// Un documento que subió el usuario (NIT, licencia, carnet…) y cómo va su revisión.
class DocumentoSubido {
  const DocumentoSubido({
    required this.id,
    required this.tipo,
    required this.nombre,
    required this.estado,
    this.observacion,
    this.negocioId,
  });

  final int id;

  /// Código del tipo ("nit", "licencia_funcionamiento", "ci_anverso"…).
  final String tipo;
  final String nombre;

  /// pendiente · aprobado · rechazado
  final String estado;

  /// Por qué se rechazó (lo escribe el admin).
  final String? observacion;

  /// Si es un documento del negocio (no de la persona).
  final int? negocioId;

  bool get aprobado => estado == 'aprobado';
  bool get rechazado => estado == 'rechazado';

  String get estadoTexto => switch (estado) {
    'aprobado' => 'Verificado',
    'rechazado' => 'Rechazado',
    _ => 'En revisión',
  };

  factory DocumentoSubido.fromJson(Map<String, dynamic> json) => DocumentoSubido(
    id: json['id'] as int,
    tipo: json['tipo'] as String,
    nombre: json['nombre'] as String,
    estado: (json['estado'] as String?) ?? 'pendiente',
    observacion: json['observacion'] as String?,
    negocioId: (json['negocio_id'] as num?)?.toInt(),
  );
}
