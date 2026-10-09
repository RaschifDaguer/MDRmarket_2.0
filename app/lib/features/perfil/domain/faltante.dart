/// Algo que le falta al usuario para usar un rol (repartidor o comerciante),
/// según `GET /api/me/faltantes/{rol}`.
class Faltante {
  const Faltante({
    required this.codigo,
    required this.texto,
    this.documento,
    this.negocioId,
    this.vehiculoId,
  });

  /// Código interno, ej. "documento.ci_reverso" o "negocio.foto:12".
  final String codigo;

  /// Texto listo para mostrar, ej. "Foto: Carnet de identidad (reverso)".
  final String texto;

  /// Si falta un documento: su tipo (ci_anverso, licencia_conducir, ruat…).
  final String? documento;
  final int? negocioId;
  final int? vehiculoId;

  bool get esDocumento => documento != null;

  factory Faltante.fromJson(Map<String, dynamic> json) => Faltante(
        codigo: json['codigo'] as String,
        texto: json['texto'] as String,
        documento: json['documento'] as String?,
        negocioId: json['negocio_id'] as int?,
        vehiculoId: json['vehiculo_id'] as int?,
      );
}
