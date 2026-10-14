import '../../../core/formato/formato.dart';
import '../../catalogo/domain/categoria.dart';
import 'horario.dart';

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
    this.nit,
    this.razonSocial,
    this.direccion,
    this.referencia,
    this.latitud,
    this.longitud,
    this.logoUrl,
    this.abierto = true,
    this.ratingPromedio,
    this.totalResenas = 0,
    this.tiempoPreparacionMin,
    this.pedidoMinimo = 0,
    this.horarios = const [],
  });

  final int id;
  final String nombre;
  final EstadoNegocio estado;
  final String? descripcion;
  final Categoria? categoria;
  final String? telefono;
  final String? nit;

  /// "Nombre para facturas" en la app.
  final String? razonSocial;
  final String? direccion;
  final String? referencia;
  final double? latitud;
  final double? longitud;
  final String? logoUrl;

  /// Interruptor manual: cerrado = no recibe pedidos.
  final bool abierto;
  final double? ratingPromedio;
  final int totalResenas;
  final int? tiempoPreparacionMin;
  final double pedidoMinimo;
  final List<Horario> horarios;

  factory Negocio.fromJson(Map<String, dynamic> json) => Negocio(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        estado: EstadoNegocio.desde(json['estado_verificacion'] as String?),
        descripcion: json['descripcion'] as String?,
        categoria: json['categoria'] is Map
            ? Categoria.fromJson(json['categoria'] as Map<String, dynamic>)
            : null,
        telefono: json['telefono'] as String?,
        nit: json['nit'] as String?,
        razonSocial: json['razon_social'] as String?,
        direccion: json['direccion'] as String?,
        referencia: json['referencia'] as String?,
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
        logoUrl: json['logo_url'] as String?,
        abierto: json['abierto'] != false,
        ratingPromedio: (json['rating_promedio'] as num?)?.toDouble(),
        totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
        tiempoPreparacionMin: (json['tiempo_preparacion_min'] as num?)?.toInt(),
        pedidoMinimo: Formato.numero(json['pedido_minimo']),
        horarios: ((json['horarios'] as List?) ?? const [])
            .map((h) => Horario.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}
