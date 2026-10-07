import 'package:flutter/material.dart';

/// Paleta de MDR Market: verde azulado (teal) + blanco.
///
/// En las pantallas usa siempre `Theme.of(context).colorScheme` (primary,
/// surface, onSurface...) y no estos valores directos: así cada pantalla
/// funciona sola en modo claro y en modo oscuro.
abstract final class AppColores {
  // --- Marca ---
  static const primario = Color(0xFF0F6E56);
  static const primarioOscuro = Color(0xFF085041);
  static const textoFuerte = Color(0xFF04342C);
  static const intermedio = Color(0xFF1D9E75);
  static const claro = Color(0xFF5DCAA5);
  static const muyClaro = Color(0xFF9FE1CB);
  static const fondoSuave = Color(0xFFE1F5EE);
  static const blanco = Color(0xFFFFFFFF);

  // --- Neutros ---
  static const arena = Color(0xFFF1EFE8);
  static const gris = Color(0xFF888780);
  static const grisOscuro = Color(0xFF5F5E5A);

  // --- Modo oscuro: la misma familia verde, pero profunda ---
  static const nocheFondo = Color(0xFF061814);
  static const nocheSuperficie = Color(0xFF0B231D);
  static const nocheBorde = Color(0xFF2A4A42);
  static const nocheTexto = Color(0xFFE4F3EE);
  static const nocheTextoSuave = Color(0xFFA9BFB8);

  /// Esquema del modo claro, definido color por color.
  static const esquemaClaro = ColorScheme(
    brightness: Brightness.light,
    primary: primario,
    onPrimary: blanco,
    primaryContainer: muyClaro,
    onPrimaryContainer: textoFuerte,
    secondary: intermedio,
    onSecondary: blanco,
    secondaryContainer: fondoSuave,
    onSecondaryContainer: primarioOscuro,
    tertiary: primarioOscuro,
    onTertiary: blanco,
    tertiaryContainer: claro,
    onTertiaryContainer: textoFuerte,
    error: Color(0xFFBA1A1A),
    onError: blanco,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: blanco,
    onSurface: textoFuerte,
    surfaceDim: Color(0xFFDCE4E0),
    surfaceBright: blanco,
    surfaceContainerLowest: blanco,
    surfaceContainerLow: Color(0xFFF6FAF8),
    surfaceContainer: Color(0xFFF2F5F3),
    surfaceContainerHigh: arena,
    surfaceContainerHighest: Color(0xFFE7E5DE),
    onSurfaceVariant: grisOscuro,
    outline: gris,
    outlineVariant: Color(0xFFDCDAD2),
    shadow: textoFuerte,
    scrim: Color(0xFF000000),
    inverseSurface: textoFuerte,
    onInverseSurface: fondoSuave,
    inversePrimary: claro,
    surfaceTint: primario,
  );

  /// Esquema del modo oscuro: fondos verde noche y acentos verde claro.
  static const esquemaOscuro = ColorScheme(
    brightness: Brightness.dark,
    primary: claro,
    onPrimary: textoFuerte,
    primaryContainer: primarioOscuro,
    onPrimaryContainer: muyClaro,
    secondary: muyClaro,
    onSecondary: textoFuerte,
    secondaryContainer: Color(0xFF0F3D33),
    onSecondaryContainer: muyClaro,
    tertiary: intermedio,
    onTertiary: blanco,
    tertiaryContainer: primario,
    onTertiaryContainer: fondoSuave,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: nocheSuperficie,
    onSurface: nocheTexto,
    surfaceDim: nocheFondo,
    surfaceBright: Color(0xFF1C3D35),
    surfaceContainerLowest: Color(0xFF04110E),
    surfaceContainerLow: Color(0xFF08201A),
    surfaceContainer: Color(0xFF0D2721),
    surfaceContainerHigh: Color(0xFF113029),
    surfaceContainerHighest: Color(0xFF173831),
    onSurfaceVariant: nocheTextoSuave,
    outline: gris,
    outlineVariant: nocheBorde,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: fondoSuave,
    onInverseSurface: textoFuerte,
    inversePrimary: primario,
    surfaceTint: claro,
  );
}
