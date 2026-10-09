import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/usuario.dart';
import '../widgets/plantilla_vista.dart';
import '../widgets/tarjeta_accion.dart';
import '../widgets/tarjeta_rol.dart';
import 'aviso_proximo_modulo.dart';

/// Vista cliente. El catálogo de productos se agrega en el próximo módulo.
/// (El saludo "Hola, nombre" ahora está en la cabecera.)
class InicioCliente extends StatelessWidget {
  const InicioCliente({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return PlantillaVista(
      tarjeta: const TarjetaRol(
        icono: Icons.shopping_bag_outlined,
        titulo: 'Catálogo de productos',
        texto: 'Aquí verás el catálogo de productos por categoría.',
        tono: TonoRol.cliente,
      ),
      extra: [
        // Cualquier cliente puede abrir su negocio sin crear otra cuenta.
        if (!usuario.vistas.contains(Vista.comerciante))
          TarjetaAccion(
            icono: Icons.storefront_outlined,
            titulo: '¿Tienes un negocio?',
            texto: 'Vende tus productos en MDR Market con tu misma cuenta.',
            boton: 'Registrar mi negocio',
            alPresionar: () => context.go('/registrar-negocio'),
          ),
      ],
      proximo: const AvisoProximoModulo(icono: Icons.shopping_bag_outlined),
    );
  }
}
