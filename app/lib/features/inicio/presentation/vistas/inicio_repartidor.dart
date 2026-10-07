import 'package:flutter/material.dart';

import '../../../auth/domain/usuario.dart';
import '../widgets/plantilla_vista.dart';
import '../widgets/tarjeta_rol.dart';
import 'aviso_proximo_modulo.dart';

/// Vista repartidor. Mientras la solicitud no esté aprobada, muestra su estado.
class InicioRepartidor extends StatelessWidget {
  const InicioRepartidor({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return switch (usuario.estadoRepartidor) {
      'aprobado' => const PlantillaVista(
          tarjeta: TarjetaRol(
            icono: Icons.delivery_dining,
            titulo: 'Listo para repartir',
            texto: 'Aquí verás los pedidos disponibles cerca de ti.',
            tono: TonoRol.repartidor,
          ),
          proximo: AvisoProximoModulo(icono: Icons.delivery_dining),
        ),
      'suspendido' => const PlantillaVista(
          tarjeta: TarjetaRol(
            icono: Icons.block,
            titulo: 'Cuenta de repartidor suspendida',
            texto: 'Comunícate con soporte para más información.',
            tono: TonoRol.alerta,
          ),
        ),
      _ => const PlantillaVista(
          tarjeta: TarjetaRol(
            icono: Icons.hourglass_top,
            titulo: 'Solicitud en revisión',
            texto: 'Estamos revisando tus documentos. Te avisaremos cuando puedas empezar a repartir.',
            tono: TonoRol.espera,
          ),
        ),
    };
  }
}
