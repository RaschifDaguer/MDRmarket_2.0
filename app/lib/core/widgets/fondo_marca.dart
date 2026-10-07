import 'package:flutter/material.dart';

/// Fondo de pantalla con dos manchas suaves de color de la marca en las
/// esquinas. Son degradados quietos: no gastan batería.
class FondoMarca extends StatelessWidget {
  const FondoMarca({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final oscuro = c.brightness == Brightness.dark;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            right: -140,
            bottom: -100,
            child: _Mancha(tamano: 360, color: c.primary.withValues(alpha: oscuro ? 0.16 : 0.10)),
          ),
          Positioned(
            left: -120,
            top: 260,
            child: _Mancha(tamano: 280, color: c.secondary.withValues(alpha: oscuro ? 0.10 : 0.08)),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Mancha extends StatelessWidget {
  const _Mancha({required this.tamano, required this.color});

  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
