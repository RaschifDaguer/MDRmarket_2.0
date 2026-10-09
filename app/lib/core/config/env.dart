import 'package:flutter/foundation.dart';

/// Configuración que cambia según dónde corre la app.
class Env {
  Env._();

  /// URL de la API Laravel.
  ///
  /// Por defecto:
  /// - Chrome (web):        http://localhost:8001/api
  /// - Emulador Android:    http://10.0.2.2:8001/api (así ve el emulador a tu PC)
  ///
  /// Para un celular real en la misma red Wi-Fi, usar la IP de la PC:
  ///   flutter run --dart-define=API_URL=http://192.168.1.50:8001/api
  static String get apiUrl {
    const desdeComando = String.fromEnvironment('API_URL');
    if (desdeComando.isNotEmpty) return desdeComando;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001/api';
    }
    return 'http://localhost:8001/api';
  }

  /// Clave de Google Maps. NUNCA se escribe en el código (el repo es público):
  /// se pasa al ejecutar, por ejemplo con el archivo local de configuración:
  ///   flutter run -d chrome --dart-define-from-file=dart_defines.local.json
  /// Sin clave, la app funciona igual pero sin mapa (solo el botón de GPS).
  static const googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');
}
