import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_controller.dart';
import 'vistas/inicio_cliente.dart';
import 'vistas/inicio_comerciante.dart';
import 'vistas/inicio_repartidor.dart';
import 'widgets/cabecera_inicio.dart';
import 'widgets/selector_vista.dart';

/// Pantalla principal. Muestra la vista activa (cliente, repartidor o
/// comerciante). El selector para cambiar de vista solo aparece si el usuario
/// tiene más de una.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario == null) return const SizedBox.shrink(); // el router redirige al login

    final vista = usuario.vistaActual;

    return Scaffold(
      body: FondoMarca(
        child: Column(
          children: [
            CabeceraInicio(
              usuario: usuario,
              vista: vista,
              alCerrarSesion: () => ref.read(authControllerProvider.notifier).logout(),
              selector: usuario.puedeCambiarVista
                  ? SelectorVista(
                      key: const Key('boton-cambiar-vista'),
                      vistas: usuario.vistas,
                      actual: vista,
                      alElegir: (elegida) => _elegirVista(context, ref, usuario, elegida),
                    )
                  : null,
            ),
            Expanded(
              // Al cambiar de vista, el contenido se funde suavemente.
              child: AnimatedSwitcher(
                duration: AppMovimiento.activo(context) ? AppMovimiento.normal : Duration.zero,
                child: KeyedSubtree(
                  key: ValueKey(vista),
                  child: switch (vista) {
                    Vista.cliente => InicioCliente(usuario: usuario),
                    Vista.repartidor => InicioRepartidor(usuario: usuario),
                    Vista.comerciante => InicioComerciante(usuario: usuario),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirVista(BuildContext context, WidgetRef ref, Usuario usuario, Vista elegida) async {
    if (elegida == usuario.vistaActual) return;

    try {
      await ref.read(authControllerProvider.notifier).cambiarVista(elegida);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}
