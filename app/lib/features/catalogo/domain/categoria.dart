/// Categoría del catálogo. Las principales traen sus subcategorías.
class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    this.icono,
    this.subcategorias = const [],
    this.soloMayores = false,
    this.permiso,
  });

  final int id;
  final String nombre;
  final String? icono;
  final List<Categoria> subcategorias;

  /// Bebidas alcohólicas: solo para mayores de 18.
  final bool soloMayores;

  /// Permiso que necesita el negocio para vender aquí: 'alcohol', 'farmacia' o null.
  final String? permiso;

  /// Nombre con su emoji adelante, ej. "🍔 Alimentos y Bebidas".
  String get etiqueta => icono == null ? nombre : '$icono $nombre';

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        icono: json['icono'] as String?,
        soloMayores: json['solo_mayores'] == true,
        permiso: json['permiso'] as String?,
        subcategorias: ((json['subcategorias'] as List?) ?? const [])
            .map((s) => Categoria.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
