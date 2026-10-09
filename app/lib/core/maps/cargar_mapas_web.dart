import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Agrega el script de Google Maps a la página y espera a que termine de
/// cargar. Se hace desde Dart (y no en web/index.html) para que la clave no
/// quede escrita en el repositorio.
Future<void> cargarGoogleMapsWeb(String clave) {
  final listo = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(clave)}';
  script.onload = ((web.Event _) => listo.complete()).toJS;
  script.onerror = ((web.Event _) => listo.completeError('no se pudo descargar el script')).toJS;
  web.document.head!.append(script);
  return listo.future.timeout(const Duration(seconds: 15));
}
