import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_movimiento.dart';

/// Sacude a [child] de lado a lado (como diciendo "no") cada vez que cambia
/// [disparo]. Sirve para avisar un error en un formulario:
///
/// ```dart
/// setState(() => _errores++);          // en la lógica de la pantalla
/// Temblor(disparo: _errores, child: …) // en el build
/// ```
class Temblor extends StatefulWidget {
  const Temblor({super.key, required this.disparo, required this.child, this.amplitud = 10});

  final int disparo;
  final Widget child;

  /// Cuántos píxeles se mueve hacia cada lado en el primer vaivén.
  final double amplitud;

  @override
  State<Temblor> createState() => _TemblorState();
}

class _TemblorState extends State<Temblor> with SingleTickerProviderStateMixin {
  late final _control = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(Temblor anterior) {
    super.didUpdateWidget(anterior);
    if (widget.disparo != anterior.disparo && AppMovimiento.activo(context)) {
      _control.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      child: widget.child,
      builder: (context, child) {
        final t = _control.value;
        // Tres vaivenes que se van apagando hasta volver al centro.
        final dx = math.sin(t * math.pi * 6) * widget.amplitud * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
