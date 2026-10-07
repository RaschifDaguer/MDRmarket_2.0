import 'package:flutter/material.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';

/// Diseño común de cada vista: la tarjeta del rol arriba y, si hay, el
/// aviso "Muy pronto" debajo. Los dos aparecen en cascada.
class PlantillaVista extends StatelessWidget {
  const PlantillaVista({super.key, required this.tarjeta, this.proximo});

  final Widget tarjeta;
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
