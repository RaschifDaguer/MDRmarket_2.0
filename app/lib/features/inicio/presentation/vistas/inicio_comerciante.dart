import 'package:flutter/material.dart';

import '../../../auth/domain/usuario.dart';
import '../widgets/plantilla_vista.dart';
import '../widgets/tarjeta_rol.dart';
import 'aviso_proximo_modulo.dart';

/// Vista comerciante. La gestión del negocio se agrega en un próximo módulo.
class InicioComerciante extends StatelessWidget {
  const InicioComerciante({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return const PlantillaVista(
      tarjeta: TarjetaRol(
        icono: Icons.storefront_outlined,
        titulo: 'Tu negocio',
        texto: 'Aquí verás tus pedidos, productos y ganancias.',
        tono: TonoRol.comerciante,
      ),
      proximo: AvisoProximoModulo(icono: Icons.storefront_outlined),
    );
  }
}
