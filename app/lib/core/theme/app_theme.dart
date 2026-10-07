import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colores.dart';
import 'app_espacios.dart';
import 'app_tipografia.dart';

/// Tema de MDR Market (Material 3) en versión clara y oscura.
/// app.dart usa los dos y elige según la configuración del equipo.
class AppTheme {
  AppTheme._();

  static ThemeData get claro => _construir(AppColores.esquemaClaro);

  static ThemeData get oscuro => _construir(AppColores.esquemaOscuro);

  static ThemeData _construir(ColorScheme c) {
    final oscuro = c.brightness == Brightness.dark;
    final radioCampo = BorderRadius.circular(AppRadios.campo);
    final formaBoton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.boton));

    OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
          borderRadius: radioCampo,
          borderSide: BorderSide(color: color, width: ancho),
        );

    // Color de íconos y etiquetas de los campos: verde al enfocar, rojo con error.
    Color colorSegunEstado(Set<WidgetState> estados) {
      if (estados.contains(WidgetState.error)) return c.error;
      if (estados.contains(WidgetState.focused)) return c.primary;
      return c.onSurfaceVariant;
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: c,
      scaffoldBackgroundColor: oscuro ? AppColores.nocheFondo : c.surfaceContainerLow,
      fontFamily: AppTipografia.familia,
      textTheme: AppTipografia.textTheme,

      // Campos rellenos; al enfocarlos el fondo se aclara y el borde se ilumina.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: WidgetStateColor.resolveWith((estados) {
          if (estados.contains(WidgetState.focused)) {
            return oscuro ? c.surfaceContainerHighest : AppColores.blanco;
          }
          return oscuro ? c.surfaceContainerHigh : AppColores.arena;
        }),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: borde(Colors.transparent),
        enabledBorder: borde(oscuro ? AppColores.nocheBorde : Colors.transparent),
        disabledBorder: borde(Colors.transparent),
        focusedBorder: borde(c.primary, 2),
        errorBorder: borde(c.error.withValues(alpha: 0.6)),
        focusedErrorBorder: borde(c.error, 2),
        prefixIconColor: WidgetStateColor.resolveWith(colorSegunEstado),
        suffixIconColor: WidgetStateColor.resolveWith(colorSegunEstado),
        labelStyle: TextStyle(color: c.onSurfaceVariant),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (estados) => TextStyle(color: colorSegunEstado(estados), fontWeight: FontWeight.w600),
        ),
        hintStyle: TextStyle(color: c.outline),
        errorStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: formaBoton,
          textStyle: AppTipografia.boton,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: formaBoton,
          textStyle: AppTipografia.boton,
          side: BorderSide(color: c.outlineVariant, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: formaBoton,
          textStyle: AppTipografia.boton.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: oscuro ? c.surfaceContainer : c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radioCampo),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      dividerTheme: DividerThemeData(color: c.outlineVariant, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.onSurface,
        scrolledUnderElevation: 0,
      ),

      // Cambio de pantalla: fundido suave; en iPhone/Mac, el deslizamiento nativo.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final plataforma in TargetPlatform.values)
            plataforma: plataforma == TargetPlatform.iOS || plataforma == TargetPlatform.macOS
                ? const CupertinoPageTransitionsBuilder()
                : const FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
