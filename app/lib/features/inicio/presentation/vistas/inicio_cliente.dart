import 'package:flutter/material.dart';

import '../../../auth/domain/usuario.dart';
import '../../../carrito/presentation/barra_carrito.dart';
import '../../../catalogo/presentation/buscar_view.dart';
import '../../../catalogo/presentation/inicio_view.dart';
import '../../../cuenta/presentation/cuenta_view.dart';
import '../../../pedidos/presentation/mis_pedidos_view.dart';

/// Vista cliente: Inicio, Buscar, Pedidos y Cuenta (pestañas abajo), con la
/// barra del carrito cuando tiene productos. Las invitaciones a vender o
/// repartir y el cambio de vista están en Cuenta.
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
      InicioView(usuario: widget.usuario),
      const BuscarView(),
      const SafeArea(bottom: false, child: MisPedidosView()),
      CuentaView(usuario: widget.usuario),
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
        // En Cuenta no hace falta el carrito.
        if (_pestana != 3) const BarraCarrito(),
        NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() {
            _pestana = i;
            _abiertas.add(i);
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.saved_search), label: 'Buscar'),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Pedidos',
            ),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
          ],
        ),
      ],
    );
  }
}
