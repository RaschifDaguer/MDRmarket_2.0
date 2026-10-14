import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/usuario.dart';
import '../../../comerciante/data/mi_negocio_repository.dart';
import '../../../comerciante/data/negocio_repository.dart';
import '../../../comerciante/presentation/pestanas/ganancias_tab.dart';
import '../../../comerciante/presentation/pestanas/mas_tab.dart';
import '../../../comerciante/presentation/pestanas/pedidos_tab.dart';
import '../../../comerciante/presentation/pestanas/productos_tab.dart';
import '../../../comerciante/presentation/pestanas/resumen_tab.dart';
import '../widgets/plantilla_vista.dart';
import '../widgets/tarjeta_accion.dart';
import '../widgets/tarjeta_rol.dart';

/// Vista comerciante. Sin negocio: invita a registrarlo. Con negocio:
/// Resumen, Productos, Pedidos, Ganancias y Más (pestañas abajo).
class InicioComerciante extends ConsumerStatefulWidget {
  const InicioComerciante({super.key, required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<InicioComerciante> createState() => _InicioComercianteState();
}

class _InicioComercianteState extends ConsumerState<InicioComerciante> {
  int _pestana = 0;
  final _abiertas = {0};

  void _ir(int pestana) => setState(() {
        _pestana = pestana;
        _abiertas.add(pestana);
      });

  @override
  Widget build(BuildContext context) {
    final negocios = ref.watch(misNegociosProvider);

    if (!negocios.hasValue) {
      if (negocios.hasError) {
        return PlantillaVista(
          tarjeta: TarjetaRol(
            icono: Icons.cloud_off_outlined,
            titulo: 'No se pudo cargar tu negocio',
            texto: '${negocios.error}',
            tono: TonoRol.alerta,
          ),
          extra: [
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(misNegociosProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final lista = negocios.value!;
    if (lista.isEmpty) {
      return PlantillaVista(
        tarjeta: const TarjetaRol(
          icono: Icons.storefront_outlined,
          titulo: 'Todavía no tienes un negocio',
          texto: 'Regístralo para empezar a vender.',
          tono: TonoRol.comerciante,
        ),
        extra: [
          TarjetaAccion(
            icono: Icons.add_business_outlined,
            titulo: 'Registra tu negocio',
            texto: 'Nombre, ubicación y una foto. Lo revisamos y te avisamos.',
            boton: 'Registrar mi negocio',
            alPresionar: () => context.go('/registrar-negocio'),
          ),
        ],
      );
    }

    // Por ahora se trabaja con el primer negocio (la base admite varios).
    final negocio = lista.first;
    final nuevos = ref.watch(resumenNegocioProvider(negocio.id)).value?.pedidosNuevos ?? 0;
    final paginas = [
      ResumenTab(negocio: negocio, alIrA: _ir),
      ProductosTab(negocio: negocio),
      PedidosTab(negocio: negocio),
      GananciasTab(negocio: negocio),
      MasTab(negocio: negocio),
    ];

    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _pestana,
            children: [
              for (var i = 0; i < paginas.length; i++) _abiertas.contains(i) ? paginas[i] : const SizedBox.shrink(),
            ],
          ),
        ),
        NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: _ir,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Resumen'),
            const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Productos'),
            NavigationDestination(
              icon: Badge(isLabelVisible: nuevos > 0, label: Text('$nuevos'), child: const Icon(Icons.receipt_long_outlined)),
              selectedIcon: Badge(isLabelVisible: nuevos > 0, label: Text('$nuevos'), child: const Icon(Icons.receipt_long)),
              label: 'Pedidos',
            ),
            const NavigationDestination(
                icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Ganancias'),
            const NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
          ],
        ),
      ],
    );
  }
}
