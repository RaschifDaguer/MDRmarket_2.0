import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;

import '../config/env.dart';
import '../theme/app_movimiento.dart';
import 'cargar_mapas_stub.dart' if (dart.library.js_interop) 'cargar_mapas_web.dart';

/// Qué mapa se muestra.
///
/// - Con `GOOGLE_MAPS_KEY`: Google Maps. En web se carga su script con la
///   clave; en Android la pone Gradle en el AndroidManifest al armar el APK
///   (ver android/app/build.gradle.kts), restringida al paquete
///   bo.mdrmarket.app y a la huella SHA-1 del certificado.
/// - Sin clave (o si Google no carga): OpenStreetMap con flutter_map, gratis y
///   sin clave (ver MapaMdr).
class Mapas {
  Mapas._();

  static bool _google = false;

  /// Se usa Google Maps (hay clave y se pudo cargar).
  static bool get google => _google;

  /// Siempre hay mapa (Google u OpenStreetMap), salvo en las pruebas, que no
  /// tienen internet: ahí solo si se pasan [teselasDePrueba].
  static bool get disponibles => !AppMovimiento.enPruebas || teselasDePrueba != null;

  /// Solo para las pruebas: teselas falsas para dibujar el mapa de
  /// OpenStreetMap sin internet (en la app queda en null).
  static TileProvider? teselasDePrueba;

  /// Se llama una vez al arrancar la app (en main.dart).
  static Future<void> preparar() async {
    if (Env.googleMapsKey.isEmpty) return;
    if (!kIsWeb) {
      _google = defaultTargetPlatform == TargetPlatform.android;
      return;
    }
    try {
      await cargarGoogleMapsWeb(Env.googleMapsKey);
      _google = true;
    } catch (e) {
      debugPrint('Google Maps no se pudo cargar (se usa OpenStreetMap): $e');
    }
  }
}
