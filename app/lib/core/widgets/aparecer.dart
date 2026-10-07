import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_movimiento.dart';

/// Hace aparecer a [child] con un fundido mientras sube suavemente.
///
/// Con [orden] se arma la "cascada": cada elemento espera un poquito más que
/// el anterior (0, 1, 2...). Si las animaciones están apagadas, se muestra quieto.
class Aparecer extends StatelessWidget {
  const Aparecer({super.key, required this.child, this.orden = 0, this.desdeAbajo = 24});

  final Widget child;
  final int orden;

  /// Cuántos píxeles más abajo empieza antes de subir a su lugar.
  final double desdeAbajo;

  @override
  Widget build(BuildContext context) {
    if (!AppMovimiento.activo(context)) return child;
    return child
        .animate(delay: AppMovimiento.pasoCascada * orden)
        .fadeIn(duration: AppMovimiento.lento, curve: AppMovimiento.curva)
        .moveY(begin: desdeAbajo, end: 0, duration: AppMovimiento.lento, curve: AppMovimiento.curva);
  }
}
