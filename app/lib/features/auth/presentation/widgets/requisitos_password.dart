import 'package:flutter/material.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../../core/theme/app_movimiento.dart';

/// Reglas de contraseña (las mismas que exige la API): mínimo 8 caracteres,
/// una mayúscula, una minúscula y un número.
class ReglasPassword {
  ReglasPassword._();

  static bool largo(String p) => p.length >= 8;
  static bool mayuscula(String p) => RegExp(r'\p{Lu}', unicode: true).hasMatch(p);
  static bool minuscula(String p) => RegExp(r'\p{Ll}', unicode: true).hasMatch(p);
  static bool numero(String p) => RegExp(r'[0-9]').hasMatch(p);
  static bool cumple(String p) => largo(p) && mayuscula(p) && minuscula(p) && numero(p);
}

/// Lista que se va marcando mientras la persona escribe la contraseña, con
/// una barra que muestra cuántos requisitos (de 4) ya cumple.
///
/// Solo usa los colores de `colorScheme`: funciona en claro, en oscuro y
/// también sin el tema de la app (como en las pruebas).
class RequisitosPassword extends StatelessWidget {
  const RequisitosPassword({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final requisitos = [
      ('Mínimo 8 caracteres', ReglasPassword.largo(password)),
      ('Una letra mayúscula', ReglasPassword.mayuscula(password)),
      ('Una letra minúscula', ReglasPassword.minuscula(password)),
      ('Un número', ReglasPassword.numero(password)),
    ];
    final cumplidos = requisitos.where((r) => r.$2).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BarraFuerza(cumplidos: cumplidos, total: requisitos.length),
        const SizedBox(height: AppEspacios.s),
        for (final (texto, cumplido) in requisitos) _Requisito(texto, cumplido),
      ],
    );
  }
}

/// Barra de 0 a 4 requisitos cumplidos que se llena con animación.
/// Rojo con 0–1, verde claro con 2–3 y verde de la marca con 4.
class _BarraFuerza extends StatelessWidget {
  const _BarraFuerza({required this.cumplidos, required this.total});

  final int cumplidos;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = switch (cumplidos) {
      0 || 1 => c.error,
      _ when cumplidos < total => c.secondary,
      _ => c.primary,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: c.outlineVariant.withValues(alpha: 0.6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: cumplidos / total),
            duration: AppMovimiento.activo(context) ? AppMovimiento.normal : Duration.zero,
            curve: AppMovimiento.curva,
            builder: (context, avance, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: avance,
              child: AnimatedContainer(
                duration: AppMovimiento.activo(context) ? AppMovimiento.normal : Duration.zero,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito(this.texto, this.cumplido);

  final String texto;
  final bool cumplido;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final colorIcono = cumplido ? c.primary : c.outline;
    final icono = Icon(
      cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
      key: ValueKey(cumplido),
      size: 18,
      color: colorIcono,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Con animaciones: el ícono "salta" al cumplirse. Sin animaciones
          // (accesibilidad o pruebas) se cambia directo: nunca hay dos íconos.
          if (AppMovimiento.activo(context))
            AnimatedSwitcher(
              duration: AppMovimiento.normal,
              transitionBuilder: (hijo, animacion) => ScaleTransition(
                scale: CurvedAnimation(parent: animacion, curve: Curves.easeOutBack),
                child: hijo,
              ),
              child: icono,
            )
          else
            icono,
          const SizedBox(width: AppEspacios.s),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                color: cumplido ? c.onSurface : c.onSurfaceVariant,
                fontWeight: cumplido ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
