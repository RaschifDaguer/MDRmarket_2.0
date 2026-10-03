import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_controller.dart';
import 'vistas/inicio_cliente.dart';
import 'vistas/inicio_comerciante.dart';
import 'vistas/inicio_repartidor.dart';

/// Pantalla principal. Muestra la vista activa (cliente, repartidor o
/// comerciante). El botón para cambiar de vista solo aparece si el usuario
/// tiene más de una.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario == null) return const SizedBox.shrink(); // el router redirige al login

    final vista = usuario.vistaActual;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MDR Market'),
            Text('Vista ${vista.etiqueta.toLowerCase()}',
                style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        actions: [
          if (usuario.puedeCambiarVista)
            IconButton(
              key: const Key('boton-cambiar-vista'),
              tooltip: 'Cambiar vista',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _elegirVista(context, ref, usuario),
            ),
          PopupMenuButton<String>(
            onSelected: (opcion) {
              if (opcion == 'salir') ref.read(authControllerProvider.notifier).logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'salir',
                child: ListTile(leading: Icon(Icons.logout), title: Text('Cerrar sesión')),
              ),
            ],
          ),
        ],
      ),
      body: switch (vista) {
        Vista.cliente => InicioCliente(usuario: usuario),
        Vista.repartidor => InicioRepartidor(usuario: usuario),
        Vista.comerciante => InicioComerciante(usuario: usuario),
      },
    );
  }

  Future<void> _elegirVista(BuildContext context, WidgetRef ref, Usuario usuario) async {
    final elegida = await showModalBottomSheet<Vista>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Cambiar a vista…', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final v in usuario.vistas)
              ListTile(
                leading: Icon(_icono(v)),
                title: Text(v.etiqueta),
                trailing: v == usuario.vistaActual ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    );
    if (elegida == null || elegida == usuario.vistaActual) return;

    try {
      await ref.read(authControllerProvider.notifier).cambiarVista(elegida);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  static IconData _icono(Vista v) => switch (v) {
        Vista.cliente => Icons.shopping_bag_outlined,
        Vista.repartidor => Icons.delivery_dining,
        Vista.comerciante => Icons.storefront_outlined,
      };
}
