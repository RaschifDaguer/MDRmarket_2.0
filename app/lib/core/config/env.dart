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
}
