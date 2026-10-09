import '../../catalogo/domain/categoria.dart';

/// Estado de revisión de un negocio (lo cambia un administrador).
enum EstadoNegocio {
  pendiente('En revisión'),
  aprobado('Activo'),
  rechazado('Rechazado'),
  suspendido('Suspendido');

  const EstadoNegocio(this.etiqueta);
  final String etiqueta;

  static EstadoNegocio desde(String? valor) =>
      EstadoNegocio.values.firstWhere((e) => e.name == valor, orElse: () => EstadoNegocio.pendiente);
}

/// Negocio de un comerciante, como lo devuelve la API.
class Negocio {
  const Negocio({
    required this.id,
    required this.nombre,
    required this.estado,
    this.descripcion,
    this.categoria,
    this.telefono,
    this.direccion,
    this.referencia,
    this.latitud,
    this.longitud,
    this.logoUrl,
    this.abierto = true,
    this.ratingPromedio,
    this.totalResenas = 0,
  });

  final int id;
  final String nombre;
  final EstadoNegocio estado;
  final String? descripcion;
  final Categoria? categoria;
  final String? telefono;
  final String? direccion;
  final String? referencia;
  final double? latitud;
  final double? longitud;
  final String? logoUrl;
  final bool abierto;
  final double? ratingPromedio;
  final int totalResenas;

  factory Negocio.fromJson(Map<String, dynamic> json) => Negocio(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        estado: EstadoNegocio.desde(json['estado_verificacion'] as String?),
        descripcion: json['descripcion'] as String?,
        categoria: json['categoria'] is Map
            ? Categoria.fromJson(json['categoria'] as Map<String, dynamic>)
            : null,
        telefono: json['telefono'] as String?,
        direccion: json['direccion'] as String?,
        referencia: json['referencia'] as String?,
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
        logoUrl: json['logo_url'] as String?,
        abierto: json['abierto'] != false,
        ratingPromedio: (json['rating_promedio'] as num?)?.toDouble(),
        totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
      );
}
