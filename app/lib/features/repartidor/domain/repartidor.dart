/// Vehículo del repartidor, según la API (`vehiculos` de `GET /api/repartidor`).
class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.tipoCodigo,
    required this.tipoNombre,
    this.placa,
    this.ruat,
    this.marca,
    this.modelo,
    this.color,
    this.anio,
    this.estado = 'pendiente',
  });

  final int id;
  final String tipoCodigo;
  final String tipoNombre;
  final String? placa;
  final String? ruat;
  final String? marca;
  final String? modelo;
  final String? color;
  final int? anio;

  /// 'pendiente', 'aprobado' o 'rechazado'.
  final String estado;

  /// "Honda XR150 · Rojo · 2022" (solo lo que tenga).
  String get detalle => [
        [marca, modelo].whereType<String>().join(' '),
        color,
        anio?.toString(),
      ].whereType<String>().where((t) => t.trim().isNotEmpty).join(' · ');

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    final tipo = json['tipo'] as Map;
    return Vehiculo(
      id: json['id'] as int,
      tipoCodigo: tipo['codigo'] as String,
      tipoNombre: tipo['nombre'] as String,
      placa: json['placa'] as String?,
      ruat: json['ruat'] as String?,
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      color: json['color'] as String?,
      anio: json['anio'] as int?,
      estado: (json['estado_verificacion'] as String?) ?? 'pendiente',
    );
  }
}

/// Mi perfil de repartidor (`GET /api/repartidor`).
class PerfilRepartidor {
  const PerfilRepartidor({required this.estado, this.motivoRechazo, this.vehiculos = const []});

  /// 'pendiente', 'aprobado', 'rechazado' o 'suspendido'.
  final String estado;

  /// Lo que escribió el administrador al rechazarlo (solo si está rechazado).
  final String? motivoRechazo;
  final List<Vehiculo> vehiculos;

  bool get rechazado => estado == 'rechazado';

  /// Por ahora, un solo vehículo en uso.
  Vehiculo? get vehiculo => vehiculos.isEmpty ? null : vehiculos.first;

  factory PerfilRepartidor.fromJson(Map<String, dynamic> json) => PerfilRepartidor(
        estado: (json['estado_verificacion'] as String?) ?? 'pendiente',
        motivoRechazo: json['motivo_rechazo'] as String?,
        vehiculos: ((json['vehiculos'] as List?) ?? const [])
            .map((v) => Vehiculo.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}
