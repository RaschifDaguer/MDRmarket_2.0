import 'package:flutter/material.dart';

import '../../../auth/domain/usuario.dart';
import 'aviso_proximo_modulo.dart';

/// Vista cliente. El catálogo de productos se agrega en el próximo módulo.
class InicioCliente extends StatelessWidget {
  const InicioCliente({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AvisoProximoModulo(
      icono: Icons.shopping_bag_outlined,
      titulo: 'Hola, ${usuario.nombre}',
      texto: 'Aquí verás el catálogo de productos por categoría.',
    );
  }
}
