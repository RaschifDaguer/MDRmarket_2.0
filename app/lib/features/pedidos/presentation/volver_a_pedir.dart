import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../carrito/presentation/carrito_controller.dart';
import '../../catalogo/data/catalogo_repository.dart';
import '../../catalogo/domain/producto.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';

/// "Volver a pedir": pone en el carrito los productos de un pedido anterior,
/// con el precio y el stock de hoy (los que ya no se venden o se agotaron se
/// avisan). Si el carrito tenía otra tienda, pregunta antes de vaciarlo.
Future<void> volverAPedir(BuildContext context, WidgetRef ref, Pedido pedido) async {
  final mensajero = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  try {
    // Los productos del pedido (la lista de pedidos no los trae).
    final detalle = pedido.items.isEmpty ? await ref.read(pedidosRepositoryProvider).pedido(pedido.id) : pedido;
    final catalogo = ref.read(catalogoRepositoryProvider);
    final disponibles = <(Producto, int)>[];
    final faltan = <String>[];
    for (final item in detalle.items) {
      try {
        final producto = (await catalogo.producto(item.productoId)).producto;
        if (producto.agotado || !producto.negocio.abierto) {
          faltan.add(item.nombre);
        } else {
          disponibles.add((producto, item.cantidad));
        }
      } on ApiException {
        faltan.add(item.nombre); // ya no está en el catálogo
      }
    }

    if (disponibles.isEmpty) {
      mensajero.showSnackBar(const SnackBar(content: Text('Esos productos ya no están disponibles.')));
      return;
    }

    final carrito = ref.read(carritoProvider);
    if (carrito != null && !carrito.vacio && carrito.negocio.id != detalle.negocioId && context.mounted) {
      final vaciar = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('¿Empezar un carrito nuevo?'),
          content: Text(
            'Tu carrito tiene productos de «${carrito.negocio.nombre}». Cada pedido es de una sola tienda.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Vaciar y seguir')),
          ],
        ),
      );
      if (vaciar != true) return;
    }

    final control = ref.read(carritoProvider.notifier);
    if (carrito != null && carrito.negocio.id != detalle.negocioId) control.vaciar();
    for (final (producto, cantidad) in disponibles) {
      control.agregar(producto, cantidad);
    }
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          faltan.isEmpty
              ? 'Listo: tu pedido está en el carrito.'
              : 'Agregamos lo disponible. Ya no hay: ${faltan.join(', ')}.',
        ),
      ),
    );
    router.push('/carrito');
  } on ApiException catch (e) {
    mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
  }
}
