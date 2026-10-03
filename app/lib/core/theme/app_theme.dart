import 'package:flutter/material.dart';

/// Colores y estilos de MDR Market (Material 3).
class AppTheme {
  AppTheme._();

  /// Color de marca: cambiando este valor cambia toda la paleta de la app.
  static const colorMarca = Color(0xFFE8590C);

  static ThemeData get claro {
    final colores = ColorScheme.fromSeed(seedColor: colorMarca);
    return ThemeData(
      colorScheme: colores,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colores.surfaceContainerLowest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
