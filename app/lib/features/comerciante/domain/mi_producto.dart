import '../../../core/formato/formato.dart';

/// Producto tal como lo ve su dueño (con costo, stock y si está oculto).
class MiProducto {
  const MiProducto({
    required this.id,
    required this.nombre,
    required this.precio,
    this.descripcion,
    this.categoriaId,
    this.categoria,
    this.costo,
    this.precioOferta,
    this.ofertaFin,
    this.enOferta = false,
    this.stock,
    this.disponible = true,
    this.tamano = 1,
    this.imagenUrl,
    this.rating,
    this.totalResenas = 0,
    this.totalVendidos = 0,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final int? categoriaId;
  final String? categoria;
  final double precio;
  final double? costo;
  final double? precioOferta;
  final DateTime? ofertaFin;
  final bool enOferta;

  /// null = sin control de stock.
  final int? stock;

  /// false = oculto en el catálogo.
  final bool disponible;

  /// Vehículo mínimo para llevarlo: 1 moto, 2 auto, 3 camión.
  final int tamano;
  final String? imagenUrl;
  final double? rating;
  final int totalResenas;
  final int totalVendidos;

  bool get sinStock => stock != null && stock! <= 0;
  double get precioVigente => enOferta && precioOferta != null ? precioOferta! : precio;

  factory MiProducto.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'] as Map?;
    double? decimal(String campo) => json[campo] == null ? null : Formato.numero(json[campo]);
    return MiProducto(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      categoriaId: (categoria?['id'] as num?)?.toInt(),
      categoria: categoria?['nombre'] as String?,
      precio: Formato.numero(json['precio']),
      costo: decimal('costo'),
      precioOferta: decimal('precio_oferta'),
      ofertaFin: Formato.fechaDe(json['oferta_fin']),
      enOferta: json['en_oferta'] == true,
      stock: (json['stock'] as num?)?.toInt(),
      disponible: json['disponible'] != false,
      tamano: (json['categoria_vehiculo_id'] as num?)?.toInt() ?? 1,
      imagenUrl: json['imagen_url'] as String?,
      rating: (json['rating_promedio'] as num?)?.toDouble(),
      totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
      totalVendidos: (json['total_vendidos'] as num?)?.toInt() ?? 0,
    );
  }
}
