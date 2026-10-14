import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../catalogo/domain/producto.dart';
import '../domain/carrito.dart';

/// Carrito de compras (en memoria). null = vacío.
class CarritoController extends Notifier<Carrito?> {
  @override
  Carrito? build() {
    // Al cerrar sesión (o cambiar de cuenta) el carrito se vacía. No al
    // terminar de cargar la sesión (de "sin usuario todavía" a la cuenta).
    ref.listen(authControllerProvider.select((s) => s.value?.id), (anterior, actual) {
      if (anterior != null && anterior != actual) state = null;
    });
    return null;
  }

  /// Agrega [cantidad] unidades. Devuelve false si el carrito tiene productos
  /// de OTRO negocio: la pantalla pregunta si se vacía (ver [reemplazarCon]).
  bool agregar(Producto producto, int cantidad) {
    final actual = state;
    if (actual != null && !actual.vacio && actual.negocio.id != producto.negocio.id) return false;

    final items = [...?actual?.items];
    final i = items.indexWhere((item) => item.producto.id == producto.id);
    final nueva = _limitar(producto, (i >= 0 ? items[i].cantidad : 0) + cantidad);
    if (i >= 0) {
      items[i] = items[i].copyWith(cantidad: nueva);
    } else {
      items.add(ItemCarrito(producto: producto, cantidad: nueva));
    }
    state = Carrito(negocio: producto.negocio, items: items);
    return true;
  }

  /// Vacía el carrito y agrega este producto (de otro negocio).
  void reemplazarCon(Producto producto, int cantidad) {
    state = null;
    agregar(producto, cantidad);
  }

  /// 0 = quitar.
  void cambiarCantidad(int productoId, int cantidad) {
    final actual = state;
    if (actual == null) return;
    final items = [
      for (final item in actual.items)
        if (item.producto.id != productoId)
          item
        else if (cantidad > 0)
          item.copyWith(cantidad: _limitar(item.producto, cantidad)),
    ];
    state = items.isEmpty ? null : Carrito(negocio: actual.negocio, items: items);
  }

  void notas(int productoId, String notas) {
    final actual = state;
    if (actual == null) return;
    state = Carrito(negocio: actual.negocio, items: [
      for (final item in actual.items)
        item.producto.id == productoId ? item.copyWith(notas: notas) : item,
    ]);
  }

  void vaciar() => state = null;

  /// Nunca más que el stock (si el producto lleva stock) ni más de 99.
  int _limitar(Producto producto, int cantidad) =>
      math.max(1, math.min(cantidad, math.min(99, producto.stock ?? 99)));
}

final carritoProvider = NotifierProvider<CarritoController, Carrito?>(CarritoController.new);
