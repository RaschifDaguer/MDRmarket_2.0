import 'dart:async';

import 'package:flutter/foundation.dart';

import 'coordenada.dart';
import 'ruta.dart';

/// La ruta por las calles mientras alguien se mueve (el repartidor en su GPS o
/// en el mapa del cliente):
/// - la pide al empezar y cuando cambian las paradas (ej. ya recogió el pedido);
/// - con cada posición calcula dónde va, cuánto falta y la próxima indicación;
/// - si se sale de la ruta (2 lecturas seguidas a más de [desvioMaximoM]), la
///   vuelve a pedir desde donde está, como mucho una vez cada [espera];
/// - si el servicio de rutas no responde, usa una línea recta y lo reintenta.
class RutaViva extends ChangeNotifier {
  RutaViva({required this.pedir, this.desvioMaximoM = 45, this.espera = const Duration(seconds: 12)});

  final Future<Ruta> Function(List<Coordenada> puntos) pedir;
  final double desvioMaximoM;
  final Duration espera;

  Ruta? _ruta;
  AvanceRuta? _avance;
  Coordenada? _origen;
  List<Coordenada> _paradas = const [];
  bool _rutaConOrigen = false;
  bool _pidiendo = false;
  bool _pidiendoConOrigen = false;
  bool _pendiente = false;
  bool _enEspera = false;
  bool _cerrado = false;
  int _desvios = 0;
  int _version = 0;
  Timer? _reloj;

  Ruta? get ruta => _ruta;
  AvanceRuta? get avance => _avance;

  /// Está pidiendo una ruta nueva (ej. "Recalculando…").
  bool get recalculando => _pidiendo && _ruta != null;

  /// La línea que falta (lo recorrido ya no se dibuja).
  List<Coordenada> get lineaRestante {
    final r = _ruta;
    if (r == null) return [?_origen, ..._paradas];
    final a = _avance;
    return a == null ? r.puntos : r.restante(a);
  }

  /// Nueva posición de quien se mueve (null si todavía no se sabe) y las paradas
  /// que le quedan en orden (ej. la tienda y la casa).
  void actualizar({required Coordenada? origen, required List<Coordenada> paradas}) {
    if (_cerrado) return;
    final otrasParadas = !listEquals(paradas, _paradas);
    _origen = origen;
    _paradas = List.unmodifiable(paradas);

    if (otrasParadas) {
      // Ej. ya recogió el pedido: la ruta vieja ya no sirve.
      _ruta = null;
      _avance = null;
      _pedir(forzar: true);
    } else if (_ruta == null) {
      _pedir(); // la primera (si ya se está pidiendo, se espera esa)
    } else if (origen != null) {
      _avance = _ruta!.avance(origen);
      _desvios = _avance!.fueraM > desvioMaximoM ? _desvios + 1 : 0;
      if (!_rutaConOrigen && !(_pidiendo && _pidiendoConOrigen)) {
        _pedir(forzar: true); // se calculó sin saber dónde estaba: enseguida, desde donde está
      } else if (_desvios >= 2) {
        _pedir(); // se salió de la ruta: otra desde donde está
      }
    }
    notifyListeners();
  }

  Future<void> _pedir({bool forzar = false}) async {
    if (_pidiendo) {
      if (forzar) _pendiente = true;
      return;
    }
    if (_enEspera && !forzar) return;
    final origen = _origen;
    final puntos = [?origen, ..._paradas];
    if (puntos.length < 2) return;

    final version = ++_version;
    _pidiendo = true;
    _pidiendoConOrigen = origen != null;
    _esperar(espera);
    Ruta nueva;
    try {
      nueva = await pedir(puntos);
      if (nueva.puntos.length < 2) nueva = Ruta.recta(puntos);
    } catch (_) {
      nueva = Ruta.recta(puntos); // sin servicio de rutas: se reintenta después de la espera
      _esperar(espera * 2);
    }
    _pidiendo = false;
    if (_cerrado) return;
    if (version == _version && !_pendiente) {
      _ruta = nueva;
      _rutaConOrigen = origen != null;
      _desvios = 0;
      final ahora = _origen;
      _avance = ahora == null ? null : nueva.avance(ahora);
      notifyListeners();
    }
    if (_pendiente) {
      _pendiente = false;
      unawaited(_pedir(forzar: true));
    }
  }

  void _esperar(Duration cuanto) {
    _reloj?.cancel();
    _enEspera = true;
    _reloj = Timer(cuanto, () => _enEspera = false);
  }

  @override
  void dispose() {
    _cerrado = true;
    _reloj?.cancel();
    super.dispose();
  }
}
