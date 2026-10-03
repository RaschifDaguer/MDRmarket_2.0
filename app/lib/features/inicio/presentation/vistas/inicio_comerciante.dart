import 'package:flutter/material.dart';

import '../../../auth/domain/usuario.dart';
import 'aviso_proximo_modulo.dart';

/// Vista comerciante. La gestión del negocio se agrega en un próximo módulo.
class InicioComerciante extends StatelessWidget {
  const InicioComerciante({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return const AvisoProximoModulo(
      icono: Icons.storefront_outlined,
      titulo: 'Tu negocio',
      texto: 'Aquí verás tus pedidos, productos y ganancias.',
    );
  }
}
