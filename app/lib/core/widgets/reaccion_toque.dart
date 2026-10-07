import 'package:flutter/widgets.dart';

import '../theme/app_movimiento.dart';

/// Encoge un poquito a [child] mientras se mantiene presionado, como si se
/// hundiera. No captura el toque: el botón de adentro lo sigue recibiendo.
class ReaccionToque extends StatefulWidget {
  const ReaccionToque({super.key, required this.child, this.escala = 0.96, this.habilitado = true});

  final Widget child;

  /// Tamaño mientras está presionado (1 = sin cambio).
  final double escala;
  final bool habilitado;

  @override
  State<ReaccionToque> createState() => _ReaccionToqueState();
}

class _ReaccionToqueState extends State<ReaccionToque> {
  bool _presionado = false;

  void _presionar(bool valor) {
    if (_presionado != valor) setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.habilitado && AppMovimiento.activo(context);
    return Listener(
      onPointerDown: activo ? (_) => _presionar(true) : null,
      onPointerUp: (_) => _presionar(false),
      onPointerCancel: (_) => _presionar(false),
      child: AnimatedScale(
        scale: activo && _presionado ? widget.escala : 1,
        duration: AppMovimiento.rapido,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
