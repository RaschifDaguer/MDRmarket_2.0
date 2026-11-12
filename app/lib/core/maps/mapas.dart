import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'cargar_mapas_stub.dart' if (dart.library.js_interop) 'cargar_mapas_web.dart';

/// Si el mapa de Google se puede mostrar en este dispositivo.
///
/// - Web: se carga el script de Google Maps con la clave de `GOOGLE_MAPS_KEY`.
/// - Android: la misma clave la pone Gradle en el AndroidManifest al armar el
///   APK (ver android/app/build.gradle.kts). Está restringida al paquete
///   bo.mdrmarket.app y a la huella SHA-1 del certificado.
/// Sin clave (o en otra plataforma), las pantallas usan solo el botón de GPS.
class Mapas {
  Mapas._();

  static bool _disponibles = false;
  static bool get disponibles => _disponibles;

  /// Se llama una vez al arrancar la app (en main.dart).
  static Future<void> preparar() async {
    if (Env.googleMapsKey.isEmpty) return;
    if (!kIsWeb) {
      _disponibles = defaultTargetPlatform == TargetPlatform.android;
      return;
    }
    try {
      await cargarGoogleMapsWeb(Env.googleMapsKey);
      _disponibles = true;
    } catch (e) {
      debugPrint('Google Maps no se pudo cargar: $e');
    }
  }
}
