import '../../../core/formato/formato.dart';
import '../../comerciante/domain/horario.dart';
import 'producto.dart';
import 'resena.dart';

/// Negocio tal como lo ve el cliente.
class Tienda {
  const Tienda({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.categoria,
    this.categoriaIcono,
    this.logoUrl,
    this.telefono,
    this.direccion,
    this.abierto = true,
    this.rating,
    this.totalResenas = 0,
    this.tiempoPreparacionMin,
    this.pedidoMinimo = 0,
    this.totalProductos,
    this.horarios = const [],
    this.envio,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final String? categoria;
  final String? categoriaIcono;
  final String? logoUrl;
  final String? telefono;
  final String? direccion;
  final bool abierto;
  final double? rating;
  final int totalResenas;
  final int? tiempoPreparacionMin;
  final double pedidoMinimo;
  final int? totalProductos;
  final List<Horario> horarios;

  /// Envío "desde", distancia y tiempo hasta el cliente. Solo si la app mandó
  /// su ubicación (null si no).
  final EnvioTienda? envio;

  /// "Abierto hasta 22:00": la hora de cierre de hoy, si cargó su horario.
  String? cierreDeHoy([DateTime? ahora]) {
    final dia = (ahora ?? DateTime.now()).weekday; // 1 = lunes, como en la API
    return horarios.where((h) => h.diaSemana == dia).map((h) => h.cierre).firstOrNull;
  }

  factory Tienda.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'] as Map?;
    return Tienda(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      categoria: categoria?['nombre'] as String?,
      categoriaIcono: categoria?['icono'] as String?,
      logoUrl: json['logo_url'] as String?,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      abierto: json['abierto'] != false,
      rating: (json['rating_promedio'] as num?)?.toDouble(),
      totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
      tiempoPreparacionMin: (json['tiempo_preparacion_min'] as num?)?.toInt(),
      pedidoMinimo: Formato.numero(json['pedido_minimo']),
      totalProductos: (json['total_productos'] as num?)?.toInt(),
      horarios: ((json['horarios'] as List?) ?? const [])
          .map((h) => Horario.fromJson(h as Map<String, dynamic>))
          .toList(),
      envio: json['envio'] is Map ? EnvioTienda.fromJson(json['envio'] as Map<String, dynamic>) : null,
    );
  }
}

/// Lo que cuesta y tarda llegar de una tienda a la ubicación del cliente.
class EnvioTienda {
  const EnvioTienda({required this.enCobertura, this.costoEnvio, this.distanciaKm, this.tiempoMin, this.tiempoMax});

  /// false: la ubicación del cliente queda fuera de la zona de reparto.
  final bool enCobertura;
  final double? costoEnvio;
  final double? distanciaKm;
  final int? tiempoMin;
  final int? tiempoMax;

  /// "15–25 min" (null fuera de cobertura).
  String? get tiempoTexto => tiempoMin == null ? null : '$tiempoMin–${tiempoMax ?? tiempoMin} min';

  factory EnvioTienda.fromJson(Map<String, dynamic> json) => EnvioTienda(
    enCobertura: json['en_cobertura'] == true,
    costoEnvio: json['costo_envio'] == null ? null : Formato.numero(json['costo_envio']),
    distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
    tiempoMin: (json['tiempo_min'] as num?)?.toInt(),
    tiempoMax: (json['tiempo_max'] as num?)?.toInt(),
  );
}

/// Página de una tienda: sus datos, productos y reseñas.
class TiendaDetalle {
  const TiendaDetalle({required this.tienda, this.productos = const [], this.resenas = const []});

  final Tienda tienda;
  final List<Producto> productos;
  final List<Resena> resenas;

  factory TiendaDetalle.fromJson(Map<String, dynamic> json) => TiendaDetalle(
    tienda: Tienda.fromJson(json),
    productos: ((json['productos'] as List?) ?? const [])
        .map((p) => Producto.fromJson(p as Map<String, dynamic>))
        .toList(),
    resenas: ((json['resenas'] as List?) ?? const []).map((r) => Resena.fromJson(r as Map<String, dynamic>)).toList(),
  );
}
