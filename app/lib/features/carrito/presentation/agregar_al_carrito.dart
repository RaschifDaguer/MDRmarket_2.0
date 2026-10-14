import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../catalogo/domain/producto.dart';
import 'carrito_controller.dart';

/// Agrega al carrito. Si ya tiene productos de otro negocio, pregunta si se
/// vacía (cada pedido va a un solo negocio). Devuelve true si se agregó.
Future<bool> agregarAlCarrito(BuildContext context, WidgetRef ref, Producto producto, int cantidad) async {
  final carrito = ref.read(carritoProvider.notifier);
  if (!carrito.agregar(producto, cantidad)) {
    final otro = ref.read(carritoProvider)?.negocio.nombre ?? 'otro negocio';
    final vaciar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Empezar un carrito nuevo?'),
        content: Text('Tu carrito tiene productos de «$otro». Cada pedido es de un solo negocio: '
            'si sigues, se vacía y se agrega «${producto.nombre}».'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Vaciar y agregar')),
        ],
      ),
    );
    if (vaciar != true) return false;
    carrito.reemplazarCon(producto, cantidad);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Agregaste ${cantidad > 1 ? '$cantidad × ' : ''}${producto.nombre}'),
        action: SnackBarAction(label: 'Ver carrito', onPressed: () => context.push('/carrito')),
        // Con botón, Flutter lo deja fijo hasta cerrarlo: así se va solo y no tapa la barra del carrito.
        persist: false,
        duration: const Duration(seconds: 3),
      ));
  }
  return true;
}
