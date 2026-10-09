import 'package:flutter/material.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';

/// Diseño común de cada vista: la tarjeta del rol arriba, debajo el contenido
/// de [extra] (si hay) y al final el aviso "Muy pronto". Aparecen en cascada.
class PlantillaVista extends StatelessWidget {
  const PlantillaVista({super.key, required this.tarjeta, this.extra = const [], this.proximo});

  final Widget tarjeta;

  /// Tarjetas o acciones propias de la vista (ej. el negocio del comerciante).
  final List<Widget> extra;
  final Widget? proximo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppEspacios.m + 4, AppEspacios.l, AppEspacios.m + 4, AppEspacios.xl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Aparecer(orden: 2, child: tarjeta),
                for (final (i, widget) in extra.indexed) ...[
                  const SizedBox(height: AppEspacios.l),
                  Aparecer(orden: 3 + i, child: widget),
                ],
                if (proximo != null) ...[
                  const SizedBox(height: AppEspacios.xl),
                  Aparecer(orden: 4, child: proximo!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
