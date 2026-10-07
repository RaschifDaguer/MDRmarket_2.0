import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colores.dart';
import '../theme/app_espacios.dart';
import '../theme/app_movimiento.dart';

/// Un ícono de producto que flota en la cabecera.
class _Flotante {
  const _Flotante(this.icono, this.posicion, this.tamano, this.profundidad, this.fase);

  final IconData icono;
  final Alignment posicion;
  final double tamano;

  /// 0 = muy al fondo (chico, tenue, se mueve poco); 1 = muy cerca.
  final double profundidad;

  /// Desfase para que no suban y bajen todos a la vez.
  final double fase;
}

const _flotantes = [
  _Flotante(Icons.local_florist_outlined, Alignment(-0.30, -0.92), 18, 0.25, 4.0),
  _Flotante(Icons.pets_outlined, Alignment(0.96, -0.05), 20, 0.35, 5.2),
  _Flotante(Icons.phone_iphone_outlined, Alignment(-0.96, 0.10), 22, 0.45, 0.7),
  _Flotante(Icons.local_pharmacy_outlined, Alignment(0.80, -0.75), 24, 0.55, 1.3),
  _Flotante(Icons.fastfood_outlined, Alignment(-0.62, 0.78), 26, 0.70, 2.1),
  _Flotante(Icons.shopping_cart_outlined, Alignment(0.40, 0.95), 22, 0.60, 3.0),
  _Flotante(Icons.shopping_bag_outlined, Alignment(-0.82, -0.62), 30, 0.90, 0.0),
  _Flotante(Icons.headphones_outlined, Alignment(0.74, 0.58), 30, 1.00, 3.4),
];

/// Cabecera verde con íconos de productos flotando a distintas profundidades.
///
/// Al mover el mouse (o arrastrar el dedo) los íconos se desplazan más o menos
/// según su profundidad: los cercanos mucho y los lejanos poco (parallax).
/// Eso da sensación de 3D sin modelos 3D: solo se mueven íconos.
///
/// [child] va centrado encima (logo, título...). Sin [altura] ocupa todo el
/// espacio disponible (como en la pantalla de arranque).
class CabeceraFlotante extends StatefulWidget {
  const CabeceraFlotante({super.key, required this.child, this.altura, this.redondeada = true});

  final Widget child;

  /// Alto sin contar la barra de estado del celular (se suma sola).
  final double? altura;

  /// Esquinas inferiores redondeadas.
  final bool redondeada;

  @override
  State<CabeceraFlotante> createState() => _CabeceraFlotanteState();
}

class _CabeceraFlotanteState extends State<CabeceraFlotante> with SingleTickerProviderStateMixin {
  /// Un solo reloj para que todos los íconos suban y bajen (ciclo de 6 s).
  late final _flotacion = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  /// Posición del puntero: de -1 a 1 en cada eje (0,0 = centro).
  Offset _puntero = Offset.zero;
  bool _activo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se vuelve a evaluar si la persona cambia "reducir movimiento".
    _activo = AppMovimiento.activo(context);
    if (_activo) {
      if (!_flotacion.isAnimating) _flotacion.repeat();
    } else {
      _flotacion.stop();
      _puntero = Offset.zero;
    }
  }

  @override
  void dispose() {
    _flotacion.dispose();
    super.dispose();
  }

  void _seguir(Offset posicion) {
    final tamano = context.size;
    if (!_activo || tamano == null || tamano.isEmpty) return;
    setState(() {
      _puntero = Offset(
        (posicion.dx / tamano.width * 2 - 1).clamp(-1.0, 1.0),
        (posicion.dy / tamano.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _soltar() {
    if (_puntero != Offset.zero) setState(() => _puntero = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final arriba = MediaQuery.paddingOf(context).top;

    final cabecera = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: oscuro
              ? const [AppColores.primarioOscuro, AppColores.textoFuerte]
              : const [AppColores.intermedio, AppColores.primario, AppColores.primarioOscuro],
        ),
        borderRadius: widget.redondeada
            ? const BorderRadius.vertical(bottom: Radius.circular(AppRadios.cabecera))
            : null,
      ),
      child: ClipRRect(
        borderRadius: widget.redondeada
            ? const BorderRadius.vertical(bottom: Radius.circular(AppRadios.cabecera))
            : BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Luces de fondo (fijas).
            const Positioned(top: -90, right: -60, child: _Luz(tamano: 260)),
            const Positioned(bottom: -120, left: -80, child: _Luz(tamano: 300)),
            // Íconos flotantes: en su propia capa para no redibujar el resto.
            RepaintBoundary(
              child: TweenAnimationBuilder<Offset>(
                tween: Tween(begin: Offset.zero, end: _puntero),
                duration: const Duration(milliseconds: 600),
                curve: AppMovimiento.curva,
                builder: (context, puntero, _) => AnimatedBuilder(
                  animation: _flotacion,
                  builder: (context, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final f in _flotantes) _icono(f, puntero, _flotacion.value),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: arriba),
              child: Center(child: widget.child),
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      onHover: (e) => _seguir(e.localPosition),
      onExit: (_) => _soltar(),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (e.kind != PointerDeviceKind.mouse) _seguir(e.localPosition);
        },
        onPointerMove: (e) {
          if (e.kind != PointerDeviceKind.mouse) _seguir(e.localPosition);
        },
        onPointerUp: (e) {
          if (e.kind != PointerDeviceKind.mouse) _soltar();
        },
        onPointerCancel: (_) => _soltar(),
        child: widget.altura == null
            ? SizedBox.expand(child: cabecera)
            : SizedBox(height: widget.altura! + arriba, width: double.infinity, child: cabecera),
      ),
    );
  }

  Widget _icono(_Flotante f, Offset puntero, double t) {
    final p = f.profundidad;
    final recorrido = 30 * p; // parallax: los cercanos se mueven más
    final flota = math.sin(t * 2 * math.pi + f.fase) * 7 * p;
    final giro = 0.35 * p;

    return Align(
      alignment: f.posicion,
      child: Transform.translate(
        offset: Offset(puntero.dx * recorrido, puntero.dy * recorrido + flota),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(-puntero.dy * giro)
            ..rotateY(puntero.dx * giro),
          child: Container(
            padding: EdgeInsets.all(f.tamano * 0.42),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06 + 0.10 * p),
              borderRadius: BorderRadius.circular(f.tamano * 0.6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08 + 0.12 * p)),
            ),
            child: Icon(
              f.icono,
              size: f.tamano * (0.75 + 0.35 * p),
              color: Colors.white.withValues(alpha: 0.40 + 0.45 * p),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo de luz difusa (degradado, sin desenfoque: es más liviano).
class _Luz extends StatelessWidget {
  const _Luz({required this.tamano});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
