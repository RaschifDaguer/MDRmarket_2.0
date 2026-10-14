import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_espacios.dart';
import 'carrito_controller.dart';

/// Barra verde abajo de la vista cliente cuando el carrito tiene algo:
/// el negocio, "Ver carrito" y el subtotal.
class BarraCarrito extends ConsumerWidget {
  const BarraCarrito({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    if (carrito == null || carrito.vacio) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.s, AppEspacios.m, AppEspacios.s),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          color: c.primary,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('barra-carrito'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/carrito'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m, vertical: AppEspacios.s + 2),
              child: Row(
                children: [
                  Badge(
                    label: Text('${carrito.unidades}'),
                    child: Icon(Icons.shopping_cart_outlined, color: c.onPrimary),
                  ),
                  const SizedBox(width: AppEspacios.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ver carrito', style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w700)),
                        Text(
                          carrito.negocio.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.onPrimary.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppEspacios.s),
                  Text(Formato.bs(carrito.subtotal), style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
