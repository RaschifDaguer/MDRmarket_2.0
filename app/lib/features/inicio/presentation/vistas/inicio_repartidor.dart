import 'package:flutter/material.dart';

import '../../../auth/domain/usuario.dart';
import 'aviso_proximo_modulo.dart';

/// Vista repartidor. Mientras la solicitud no esté aprobada, muestra su estado.
class InicioRepartidor extends StatelessWidget {
  const InicioRepartidor({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return switch (usuario.estadoRepartidor) {
      'aprobado' => const AvisoProximoModulo(
          icono: Icons.delivery_dining,
          titulo: 'Listo para repartir',
          texto: 'Aquí verás los pedidos disponibles cerca de ti.',
        ),
      'suspendido' => const AvisoProximoModulo(
          icono: Icons.block,
          titulo: 'Cuenta de repartidor suspendida',
          texto: 'Comunícate con soporte para más información.',
          esProximoModulo: false,
        ),
      _ => const AvisoProximoModulo(
          icono: Icons.hourglass_top,
          titulo: 'Solicitud en revisión',
          texto: 'Estamos revisando tus documentos. Te avisaremos cuando puedas empezar a repartir.',
          esProximoModulo: false,
        ),
    };
  }
}
