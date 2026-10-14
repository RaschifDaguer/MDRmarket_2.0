import '../../catalogo/domain/producto.dart';

/// Un producto en el carrito con su cantidad.
class ItemCarrito {
  const ItemCarrito({required this.producto, required this.cantidad, this.notas});

  final Producto producto;
  final int cantidad;

  /// Ej. "sin cebolla".
  final String? notas;

  double get subtotal => producto.precioFinal * cantidad;

  ItemCarrito copyWith({int? cantidad, String? notas}) =>
      ItemCarrito(producto: producto, cantidad: cantidad ?? this.cantidad, notas: notas ?? this.notas);
}

/// Carrito: productos de UN negocio (cada pedido va a un solo negocio).
class Carrito {
  const Carrito({required this.negocio, this.items = const []});

  final NegocioResumen negocio;
  final List<ItemCarrito> items;

  int get unidades => items.fold(0, (total, i) => total + i.cantidad);
  double get subtotal => items.fold(0, (total, i) => total + i.subtotal);
  bool get vacio => items.isEmpty;

  int cantidadDe(int productoId) =>
      items.where((i) => i.producto.id == productoId).fold(0, (total, i) => total + i.cantidad);
}
