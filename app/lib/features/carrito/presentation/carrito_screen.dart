import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../catalogo/data/catalogo_repository.dart';
import '../domain/carrito.dart';
import 'carrito_controller.dart';

/// Carrito: cantidades, notas por producto y el subtotal. Sigue a /checkout.
class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    if (carrito == null || carrito.vacio) {
      return Pantalla(
        titulo: 'Tu carrito',
        child: EstadoVacio(
          icono: Icons.shopping_cart_outlined,
          titulo: 'Tu carrito está vacío',
          texto: 'Agrega productos desde el catálogo.',
          accion: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => context.go('/inicio'),
            child: const Text('Ver productos'),
          ),
        ),
      );
    }

    // Pedido mínimo del negocio (viene con el detalle de la tienda).
    final tienda = ref.watch(tiendaDetalleProvider(carrito.negocio.id)).value?.tienda;
    final minimo = tienda?.pedidoMinimo ?? 0;
    final falta = minimo - carrito.subtotal;
    final controlador = ref.read(carritoProvider.notifier);

    return Pantalla(
      titulo: 'Tu carrito',
      acciones: [
        TextButton(
          onPressed: () async {
            final vaciar = await showDialog<bool>(
              context: context,
              builder: (contexto) => AlertDialog(
                title: const Text('¿Vaciar el carrito?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Vaciar')),
                ],
              ),
            );
            if (vaciar == true) controlador.vaciar();
          },
          child: const Text('Vaciar'),
        ),
      ],
      abajo: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (falta > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppEspacios.s),
                child: Text(
                  'El pedido mínimo de ${carrito.negocio.nombre} es ${Formato.bs(minimo)}. Te faltan ${Formato.bs(falta)}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            BotonPrincipal(
              texto: 'Continuar · ${Formato.bs(carrito.subtotal)}',
              icono: Icons.arrow_forward,
              onPressed: falta > 0 ? null : () => context.push('/checkout'),
            ),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ImagenRed(carrito.negocio.logoUrl, ancho: 44, alto: 44, radio: 12, icono: Icons.storefront),
            title: Text(carrito.negocio.nombre, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text('${carrito.unidades} producto${carrito.unidades == 1 ? '' : 's'}'),
            trailing: TextButton(
              onPressed: () => context.push('/tienda/${carrito.negocio.id}'),
              child: const Text('Agregar más'),
            ),
          ),
          const SizedBox(height: AppEspacios.s),
          for (final item in carrito.items) ...[
            _FilaItem(item: item, controlador: controlador),
            const SizedBox(height: AppEspacios.s),
          ],
          const Divider(height: AppEspacios.l),
          Row(
            children: [
              Text('Subtotal', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(Formato.bs(carrito.subtotal), style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppEspacios.xs),
          Text('El costo del envío se calcula en el siguiente paso.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({required this.item, required this.controlador});

  final ItemCarrito item;
  final CarritoController controlador;

  @override
  Widget build(BuildContext context) {
    final p = item.producto;
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m - 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImagenRed(p.imagenUrl, ancho: 64, alto: 64, radio: 12),
            const SizedBox(width: AppEspacios.m - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nombre, style: textos.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${Formato.bs(p.precioFinal)} c/u', style: textos.bodySmall),
                  if (item.notas != null && item.notas!.isNotEmpty)
                    Text('Nota: ${item.notas}', style: textos.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  const SizedBox(height: AppEspacios.s),
                  Wrap(
                    spacing: AppEspacios.s,
                    runSpacing: AppEspacios.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SelectorCantidad(
                        compacto: true,
                        minimo: 0,
                        valor: item.cantidad,
                        maximo: (p.stock ?? 99).clamp(1, 99),
                        alCambiar: (n) => controlador.cambiarCantidad(p.id, n),
                      ),
                      TextButton.icon(
                        onPressed: () => _editarNota(context),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: Text(item.notas == null || item.notas!.isEmpty ? 'Agregar nota' : 'Editar nota'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(Formato.bs(item.subtotal), style: textos.titleSmall),
          ],
        ),
      ),
    );
  }

  Future<void> _editarNota(BuildContext context) async {
    final control = TextEditingController(text: item.notas);
    final nota = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Nota para «${item.producto.nombre}»'),
        content: TextField(
          controller: control,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(hintText: 'Ej. sin cebolla, bien cocido…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, control.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    control.dispose();
    if (nota != null) controlador.notas(item.producto.id, nota);
  }
}
