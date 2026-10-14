import '../../../core/formato/formato.dart';
import 'resena.dart';

/// Negocio en pocas palabras (lo que se muestra junto a un producto).
class NegocioResumen {
  const NegocioResumen({required this.id, required this.nombre, this.logoUrl, this.rating, this.abierto = true});

  final int id;
  final String nombre;
  final String? logoUrl;
  final double? rating;
  final bool abierto;

  factory NegocioResumen.fromJson(Map<String, dynamic> json) => NegocioResumen(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        logoUrl: json['logo_url'] as String?,
        rating: (json['rating_promedio'] as num?)?.toDouble(),
        abierto: json['abierto'] != false,
      );
}

/// Producto del catálogo, con el precio final (ya con la oferta vigente).
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.precioFinal,
    required this.negocio,
    this.descripcion,
    this.enOferta = false,
    this.descuentoPct = 0,
    this.stock,
    this.rating,
    this.totalResenas = 0,
    this.imagenUrl,
    this.categoria,
    this.categoriaIcono,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final double precioFinal;
  final bool enOferta;
  final int descuentoPct;

  /// null = sin control de stock (siempre disponible).
  final int? stock;
  final double? rating;
  final int totalResenas;
  final String? imagenUrl;
  final String? categoria;
  final String? categoriaIcono;
  final NegocioResumen negocio;

  bool get agotado => stock != null && stock! <= 0;

  factory Producto.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'] as Map?;
    return Producto(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precio: Formato.numero(json['precio']),
      precioFinal: Formato.numero(json['precio_final']),
      enOferta: json['en_oferta'] == true,
      descuentoPct: (json['descuento_pct'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt(),
      rating: (json['rating_promedio'] as num?)?.toDouble(),
      totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
      imagenUrl: json['imagen_url'] as String?,
      categoria: categoria?['nombre'] as String?,
      categoriaIcono: categoria?['icono'] as String?,
      negocio: NegocioResumen.fromJson(json['negocio'] as Map<String, dynamic>),
    );
  }
}

/// Detalle de un producto: todas sus fotos, reseñas y datos del negocio.
class ProductoDetalle {
  const ProductoDetalle({
    required this.producto,
    this.imagenes = const [],
    this.resenas = const [],
    this.pedidoMinimo = 0,
    this.tiempoPreparacionMin,
  });

  final Producto producto;
  final List<String> imagenes;
  final List<Resena> resenas;
  final double pedidoMinimo;
  final int? tiempoPreparacionMin;

  factory ProductoDetalle.fromJson(Map<String, dynamic> json) {
    final negocio = json['negocio'] as Map<String, dynamic>;
    return ProductoDetalle(
      producto: Producto.fromJson(json),
      imagenes: ((json['imagenes'] as List?) ?? const []).cast<String>(),
      resenas: ((json['resenas'] as List?) ?? const []).map((r) => Resena.fromJson(r as Map<String, dynamic>)).toList(),
      pedidoMinimo: Formato.numero(negocio['pedido_minimo']),
      tiempoPreparacionMin: (negocio['tiempo_preparacion_min'] as num?)?.toInt(),
    );
  }
}
