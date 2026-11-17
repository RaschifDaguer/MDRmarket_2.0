import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_controller.dart';

/// Pestaña "Cuenta" del repartidor: sus datos, el tema (el mismo para toda la
/// app), volver a la vista cliente y cerrar sesión.
class CuentaRepartidor extends ConsumerWidget {
  const CuentaRepartidor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    Future<void> aCliente() async {
      try {
        await ref.read(authControllerProvider.notifier).cambiarVista(Vista.cliente);
      } on ApiException catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppEspacios.m),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mi cuenta', style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (usuario != null) ...[
                  const SizedBox(height: AppEspacios.s),
                  Text(usuario.nombreCompleto, style: textos.titleMedium),
                  Text(usuario.email, style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ],
                const SizedBox(height: AppEspacios.m),
                const Card(child: SelectorTema()),
                const SizedBox(height: AppEspacios.m),
                OutlinedButton.icon(
                  key: const Key('repartidor-a-cliente'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: aCliente,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Cambiar a vista cliente'),
                ),
                const SizedBox(height: AppEspacios.s),
                TextButton.icon(
                  key: const Key('cerrar-sesion-repartidor'),
                  style: TextButton.styleFrom(foregroundColor: c.error, minimumSize: const Size.fromHeight(48)),
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
