import 'package:flutter/material.dart';

/// Tipografía de la app: Plus Jakarta Sans (en assets/fonts, declarada en
/// pubspec.yaml con los pesos 400, 500, 600 y 700).
abstract final class AppTipografia {
  /// Nombre de la familia tal como está en pubspec.yaml.
  static const familia = 'PlusJakartaSans';

  /// Solo ajusta grosor y espaciado de letras; los tamaños y colores los pone
  /// Material 3. Los títulos van más gruesos y un poco más juntos (look moderno).
  static const textTheme = TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -1.2),
    displayMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -1.0),
    displaySmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.8),
    headlineLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.6),
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleMedium: TextStyle(fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: TextStyle(fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontWeight: FontWeight.w500),
  );

  /// Estilo de los botones (necesita la familia porque reemplaza al del tema).
  static const boton = TextStyle(
    fontFamily: familia,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
}
