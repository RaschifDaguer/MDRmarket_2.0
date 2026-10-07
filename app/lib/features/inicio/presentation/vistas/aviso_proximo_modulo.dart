import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../../core/theme/app_movimiento.dart';

/// Ilustración animada "Muy pronto" para las vistas que todavía no tienen su
/// contenido real: el ícono del módulo flota en el centro y unas
/// herramientas giran alrededor. Hecha solo con íconos (sin imágenes).
class AvisoProximoModulo extends StatefulWidget {
  const AvisoProximoModulo({super.key, required this.icono});

  /// Ícono del módulo que viene (va en el centro).
  final IconData icono;

  @override
  State<AvisoProximoModulo> createState() => _AvisoProximoModuloState();
}

class _AvisoProximoModuloState extends State<AvisoProximoModulo> with SingleTickerProviderStateMixin {
  /// Una vuelta completa de la órbita cada 14 s.
  late final _orbita = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  static const _satelites = [
    Icons.construction,
    Icons.auto_awesome,
    Icons.build_outlined,
    Icons.rocket_launch_outlined,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMovimiento.activo(context)) {
      if (!_orbita.isAnimating) _orbita.repeat();
    } else {
      _orbita.stop();
    }
  }

  @override
  void dispose() {
    _orbita.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final animar = AppMovimiento.activo(context);

    Widget centro = Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.primaryContainer, c.secondaryContainer],
        ),
        boxShadow: [
          BoxShadow(color: c.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Icon(widget.icono, size: 48, color: c.onPrimaryContainer),
    );
    if (animar) {
      // Sube y baja suavemente, sin parar.
      centro = centro
          .animate(onPlay: (control) => control.repeat(reverse: true))
          .moveY(begin: -5, end: 5, duration: 1800.ms, curve: Curves.easeInOut);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Anillo de la órbita.
              Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.outlineVariant, width: 1.5),
                ),
              ),
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _orbita,
                  builder: (context, _) {
                    final giro = _orbita.value * 2 * math.pi;
                    return SizedBox.square(
                      dimension: 176,
                      child: Stack(
                        children: [
                          for (var i = 0; i < _satelites.length; i++)
                            Align(
                              alignment: Alignment(
                                math.cos(giro + i * math.pi / 2),
                                math.sin(giro + i * math.pi / 2),
                              ),
                              child: _Satelite(_satelites[i]),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              centro,
            ],
          ),
        ),
        const SizedBox(height: AppEspacios.m),
        Text('Muy pronto', style: textos.titleLarge),
        const SizedBox(height: AppEspacios.xs),
        Text(
          'Estamos construyendo esta sección.',
          textAlign: TextAlign.center,
          style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppEspacios.m - 4),
        Chip(
          label: const Text('Próximo módulo'),
          avatar: Icon(Icons.construction, size: 18, color: c.primary),
          side: BorderSide(color: c.outlineVariant),
          shape: const StadiumBorder(),
        ),
      ],
    );
  }
}

/// Pequeña burbuja con un ícono que gira en la órbita.
class _Satelite extends StatelessWidget {
  const _Satelite(this.icono);

  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface,
        border: Border.all(color: c.outlineVariant),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Icon(icono, size: 18, color: c.primary),
    );
  }
}
