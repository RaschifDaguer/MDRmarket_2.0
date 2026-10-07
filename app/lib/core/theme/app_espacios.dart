import 'package:flutter/material.dart';

/// Espaciados de la app. Usa siempre estos valores para que todo respire igual.
abstract final class AppEspacios {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Qué tan redondeadas son las esquinas de cada pieza.
abstract final class AppRadios {
  static const double campo = 14;
  static const double boton = 16;
  static const double tarjeta = 24;
  static const double cabecera = 32;
}

/// Sombras suaves (dan "profundidad" sin verse pesadas).
abstract final class AppSombras {
  /// Sombra de tarjeta. [desfase] la mueve (la usa la tarjeta 3D al inclinarse).
  static List<BoxShadow> tarjeta(Color base, {Offset desfase = Offset.zero}) => [
        BoxShadow(
          color: base.withValues(alpha: 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2) + desfase * 0.3,
        ),
        BoxShadow(
          color: base.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 16) + desfase,
        ),
      ];

  /// Resplandor de color debajo de un botón principal.
  static List<BoxShadow> brillo(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}
