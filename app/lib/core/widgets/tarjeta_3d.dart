import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_espacios.dart';
import '../theme/app_movimiento.dart';

/// Tarjeta que se inclina en perspectiva siguiendo al mouse (o al dedo
/// mientras se mantiene presionada) y vuelve a quedar plana al soltarla.
///
/// Es un efecto "2.5D": solo se gira el dibujo con una matriz ([Matrix4]),
/// así que es muy liviano incluso en celulares sencillos.
class Tarjeta3D extends StatefulWidget {
  const Tarjeta3D({
    super.key,
    required this.child,
    this.inclinacionMax = 8,
    this.padding = const EdgeInsets.all(AppEspacios.l),
    this.reaccionarAlDedo = true,
  });

  final Widget child;

  /// Ángulo máximo de inclinación, en grados.
  final double inclinacionMax;
  final EdgeInsetsGeometry padding;

  /// `false` en tarjetas con formularios: así no se mueve al tocar un campo
  /// en el celular (con mouse sigue inclinándose).
  final bool reaccionarAlDedo;

  @override
  State<Tarjeta3D> createState() => _Tarjeta3DState();
}

class _Tarjeta3DState extends State<Tarjeta3D> {
  /// Hacia dónde está inclinada: x e y van de -1 a 1 (0,0 = plana).
  Offset _inclinacion = Offset.zero;

  void _seguir(Offset posicion) {
    final tamano = context.size;
    if (tamano == null || tamano.isEmpty) return;
    setState(() {
      _inclinacion = Offset(
        (posicion.dx / tamano.width * 2 - 1).clamp(-1.0, 1.0),
        (posicion.dy / tamano.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _soltar() {
    if (_inclinacion != Offset.zero) setState(() => _inclinacion = Offset.zero);
  }

  void _dedo(PointerEvent e) {
    if (widget.reaccionarAlDedo && e.kind != PointerDeviceKind.mouse) _seguir(e.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(padding: widget.padding, child: widget.child);
    if (!AppMovimiento.activo(context)) return _dibujar(context, Offset.zero, contenido);

    return MouseRegion(
      onHover: (e) => _seguir(e.localPosition),
      onExit: (_) => _soltar(),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _dedo,
        onPointerMove: _dedo,
        onPointerUp: (e) {
          if (e.kind != PointerDeviceKind.mouse) _soltar();
        },
        onPointerCancel: (_) => _soltar(),
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(begin: Offset.zero, end: _inclinacion),
          duration: const Duration(milliseconds: 220),
          curve: AppMovimiento.curva,
          child: contenido,
          builder: (context, v, child) {
            final angulo = widget.inclinacionMax * math.pi / 180;
            final matriz = Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // perspectiva: lo cercano se ve más grande
              ..rotateX(v.dy * angulo) // el lado señalado se "hunde"
              ..rotateY(-v.dx * angulo);
            return Transform(
              alignment: Alignment.center,
              transform: matriz,
              child: _dibujar(context, v, child!),
            );
          },
        ),
      ),
    );
  }

  /// Fondo, borde, sombra (que se corre al inclinarse) y un brillo suave
  /// que sigue al puntero.
  Widget _dibujar(BuildContext context, Offset v, Widget child) {
    final c = Theme.of(context).colorScheme;
    final oscuro = c.brightness == Brightness.dark;
    final radio = BorderRadius.circular(AppRadios.tarjeta);
    final fuerza = v.distance.clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: oscuro ? c.surfaceContainer : c.surface,
        borderRadius: radio,
        border: Border.all(color: c.outlineVariant.withValues(alpha: oscuro ? 0.9 : 0.5)),
        boxShadow: AppSombras.tarjeta(c.shadow, desfase: Offset(-v.dx * 10, -v.dy * 10)),
      ),
      foregroundDecoration: fuerza == 0
          ? null
          : BoxDecoration(
              borderRadius: radio,
              gradient: RadialGradient(
                center: Alignment(v.dx, v.dy),
                radius: 1.2,
                colors: [
                  Colors.white.withValues(alpha: (oscuro ? 0.06 : 0.16) * fuerza),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
      child: child,
    );
  }
}
