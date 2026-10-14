import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../auth/domain/usuario.dart';
import '../../../carrito/presentation/barra_carrito.dart';
import '../../../catalogo/presentation/catalogo_view.dart';
import '../../../catalogo/presentation/tiendas_view.dart';
import '../../../pedidos/presentation/mis_pedidos_view.dart';

/// Vista cliente: catálogo, tiendas y mis pedidos (pestañas abajo), con la
/// barra del carrito cuando tiene productos.
class InicioCliente extends StatefulWidget {
  const InicioCliente({super.key, required this.usuario});

  final Usuario usuario;

  @override
  State<InicioCliente> createState() => _InicioClienteState();
}

class _InicioClienteState extends State<InicioCliente> {
  int _pestana = 0;

  /// Las pestañas se arman recién la primera vez que se abren (así no se
  /// piden a la API cosas que la persona no mira).
  final _abiertas = {0};

  @override
  Widget build(BuildContext context) {
    final paginas = [
      CatalogoView(
        // Cualquier cliente puede abrir su negocio sin crear otra cuenta.
        encabezado: widget.usuario.vistas.contains(Vista.comerciante) ? null : const _InvitacionNegocio(),
      ),
      const TiendasView(),
      const MisPedidosView(),
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
        const BarraCarrito(),
        NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() {
            _pestana = i;
            _abiertas.add(i);
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(
                icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Tiendas'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
          ],
        ),
      ],
    );
  }
}

/// "¿Tienes un negocio?" en pequeño, arriba del catálogo.
class _InvitacionNegocio extends StatelessWidget {
  const _InvitacionNegocio();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Card(
      color: c.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m - 4, vertical: AppEspacios.s),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, color: c.onSecondaryContainer),
            const SizedBox(width: AppEspacios.m - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Tienes un negocio?', style: textos.titleSmall),
                  Text('Vende en MDR Market con tu misma cuenta.', style: textos.bodySmall),
                ],
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => context.go('/registrar-negocio'),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
