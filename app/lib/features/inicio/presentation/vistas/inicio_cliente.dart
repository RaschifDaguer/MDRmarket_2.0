import 'package:flutter/material.dart';

import '../../../auth/domain/usuario.dart';
import '../widgets/plantilla_vista.dart';
import '../widgets/tarjeta_rol.dart';
import 'aviso_proximo_modulo.dart';

/// Vista cliente. El catálogo de productos se agrega en el próximo módulo.
/// (El saludo "Hola, nombre" ahora está en la cabecera.)
class InicioCliente extends StatelessWidget {
  const InicioCliente({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return const PlantillaVista(
      tarjeta: TarjetaRol(
        icono: Icons.shopping_bag_outlined,
        titulo: 'Catálogo de productos',
        texto: 'Aquí verás el catálogo de productos por categoría.',
        tono: TonoRol.cliente,
      ),
      proximo: AvisoProximoModulo(icono: Icons.shopping_bag_outlined),
    );
  }
}
