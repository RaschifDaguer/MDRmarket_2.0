import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'cargar_mapas_stub.dart' if (dart.library.js_interop) 'cargar_mapas_web.dart';

/// Si el mapa de Google se puede mostrar en este dispositivo.
///
/// - Web: se carga el script de Google Maps con la clave de `GOOGLE_MAPS_KEY`.
/// - Android/iOS: todavía no está configurado (se hace al compilar para celular).
/// Si no hay mapa, las pantallas usan solo el botón de GPS.
class Mapas {
  Mapas._();

  static bool _disponibles = false;
  static bool get disponibles => _disponibles;

  /// Se llama una vez al arrancar la app (en main.dart).
  static Future<void> preparar() async {
    if (!kIsWeb || Env.googleMapsKey.isEmpty) return;
    try {
      await cargarGoogleMapsWeb(Env.googleMapsKey);
      _disponibles = true;
    } catch (e) {
      debugPrint('Google Maps no se pudo cargar: $e');
    }
  }
}
