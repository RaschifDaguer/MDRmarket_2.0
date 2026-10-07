import 'package:flutter/material.dart';

/// Duraciones y curvas de las animaciones, y la regla de cuándo animar.
abstract final class AppMovimiento {
  static const rapido = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const lento = Duration(milliseconds: 500);

  /// Espera entre un elemento y el siguiente en la aparición en cascada.
  static const pasoCascada = Duration(milliseconds: 70);

  static const curva = Curves.easeOutCubic;

  /// `true` cuando corre dentro de `flutter test`: las pruebas usan su propio
  /// "binding", que no es el WidgetsFlutterBinding de la app real.
  static bool get enPruebas => WidgetsBinding.instance is! WidgetsFlutterBinding;

  /// ¿Se puede animar? No, si la persona pidió "reducir movimiento" en su
  /// equipo (accesibilidad) ni en las pruebas (las animaciones infinitas
  /// colgarían `pumpAndSettle`). En esos casos todo se muestra quieto.
  static bool activo(BuildContext context) =>
      !enPruebas && !MediaQuery.disableAnimationsOf(context);
}
