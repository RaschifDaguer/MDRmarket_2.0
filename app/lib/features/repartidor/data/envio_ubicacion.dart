import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_exception.dart';
import 'repartidor_repository.dart';

/// Una lectura del GPS: el punto, o por qué no hay.
class LecturaGps {
  const LecturaGps(this.punto, {this.sinPermiso = false, this.gpsApagado = false});

  final Coordenada? punto;

  /// No dio permiso de ubicación (o lo negó para siempre).
  final bool sinPermiso;

  /// La ubicación (GPS) del teléfono está apagada.
  final bool gpsApagado;

  bool get falla => sinPermiso || gpsApagado;
}

/// Cómo se lee el GPS mientras reparte. En Android, con un servicio en primer
/// plano (la notificación "Llevando un pedido"): así sigue leyendo con la
/// pantalla apagada o la app en segundo plano, que es lo normal mientras maneja.
/// Sin eso, Android deja de dar la ubicación a los pocos segundos.
LocationSettings ajustesGpsReparto() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Llevando un pedido',
        notificationText: 'MDR Market comparte tu ubicación con el cliente hasta que lo entregues.',
        notificationChannelName: 'Ubicación durante el reparto',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
}

/// Sigue el GPS (una lectura cada vez que se mueve unos metros). Revisa antes
/// que esté encendido y con permiso, y avisa si se apaga en el camino.
Stream<LecturaGps> seguirGps() async* {
  if (!await Geolocator.isLocationServiceEnabled()) {
    yield const LecturaGps(null, gpsApagado: true);
    return;
  }
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
  if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
    yield const LecturaGps(null, sinPermiso: true);
    return;
  }
  // Mientras llega la primera lectura precisa, la última conocida (si es reciente).
  try {
    final ultima = kIsWeb ? null : await Geolocator.getLastKnownPosition();
    if (ultima != null && DateTime.now().difference(ultima.timestamp) < const Duration(minutes: 2)) {
      yield LecturaGps(Coordenada(ultima.latitude, ultima.longitude));
    }
  } catch (_) {}
  yield* Geolocator.getPositionStream(locationSettings: ajustesGpsReparto()).transform(
    StreamTransformer<Position, LecturaGps>.fromHandlers(
      handleData: (p, salida) => salida.add(LecturaGps(Coordenada(p.latitude, p.longitude))),
      handleError: (e, _, salida) => salida.add(
        LecturaGps(null, gpsApagado: e is LocationServiceDisabledException, sinPermiso: e is PermissionDeniedException),
      ),
    ),
  );
}

/// De dónde sale el GPS. Las pruebas lo reemplazan.
final fuenteGpsProvider = Provider<Stream<LecturaGps> Function()>((ref) => seguirGps);

/// Abre los ajustes para encender la ubicación (o el permiso de la app). Las pruebas lo reemplazan.
final abrirAjustesGpsProvider = Provider<Future<void> Function(LecturaGps)>(
  (ref) => (lectura) async {
    if (kIsWeb) return; // en el navegador, el permiso se da en el candado de la barra de direcciones
    if (lectura.gpsApagado) {
      await Geolocator.openLocationSettings();
    } else if (await Geolocator.checkPermission() == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.requestPermission();
    }
  },
);

enum EstadoGps { inactivo, buscando, enviando, sinPermiso, gpsApagado }

/// La última posición del repartidor que se leyó del GPS (para su mapa y su modo GPS).
class MiUbicacion extends Notifier<Coordenada?> {
  @override
  Coordenada? build() => null;

  void poner(Coordenada punto) => state = punto;
}

final miUbicacionProvider = NotifierProvider<MiUbicacion, Coordenada?>(MiUbicacion.new);

/// Mientras el repartidor lleva un pedido (listo para recoger o en camino),
/// sigue su GPS y lo manda a la API para que el cliente lo vea moverse:
/// - cada lectura nueva actualiza enseguida su propio mapa;
/// - a la API manda como mucho una cada [minimoEntreEnvios] (acepta una cada 3 s);
/// - si está quieto, igual repite la última cada [latido] (el cliente ve que sigue conectado);
/// - si se corta internet, manda la más reciente cuando vuelve;
/// - si el GPS se apaga o falta el permiso, avisa y reintenta solo (y al volver a la app).
/// Deja de mandar al entregar o soltar el pedido, o si lo cancelaron.
class EnvioUbicacion extends Notifier<EstadoGps> {
  static const minimoEntreEnvios = Duration(seconds: 4);
  static const latido = Duration(seconds: 15);
  static const reintentoGps = Duration(seconds: 8);

  StreamSubscription<LecturaGps>? _gps;
  Timer? _relojLatido;
  Timer? _relojEnvio;
  Timer? _relojReintento;
  AppLifecycleListener? _ciclo;
  LecturaGps? _ultimaFalla;
  Coordenada? _ultimo;
  bool _hayNuevo = false;
  bool _puedeEnviar = true;
  bool _enviando = false;
  bool _envioDesdeLatido = false;

  @override
  EstadoGps build() {
    // Solo el número del pedido: la pantalla lo actualiza cada pocos segundos y
    // si se vigilara el pedido entero, cada actualización reiniciaría el GPS.
    final pedidoId = ref.watch(pedidoActualProvider.select((actual) => actual.value?.id));
    if (pedidoId == null) return EstadoGps.inactivo;

    ref.onDispose(_parar);
    _relojLatido = Timer.periodic(latido, (_) => _alLatir());
    _ciclo = AppLifecycleListener(onResume: () {
      if (state == EstadoGps.sinPermiso || state == EstadoGps.gpsApagado) reintentar();
    });
    Future.microtask(_escuchar);
    return EstadoGps.buscando;
  }

  void _escuchar() {
    if (!ref.mounted) return;
    _gps?.cancel();
    _gps = ref.read(fuenteGpsProvider)().listen(
      _alLeer,
      onError: (_) => _alLeer(const LecturaGps(null, gpsApagado: true)),
      cancelOnError: false,
    );
  }

  /// Vuelve a intentar leer el GPS (ej. después de encenderlo).
  void reintentar() {
    if (!ref.mounted) return;
    _relojReintento?.cancel();
    if (state != EstadoGps.enviando) state = EstadoGps.buscando;
    _escuchar();
  }

  /// Abre los ajustes del teléfono para encender la ubicación o dar el permiso.
  Future<void> activarUbicacion() async {
    final falla = _ultimaFalla ?? const LecturaGps(null, sinPermiso: true);
    await ref.read(abrirAjustesGpsProvider)(falla);
    reintentar();
  }

  void _alLeer(LecturaGps lectura) {
    if (!ref.mounted) return;
    if (lectura.falla) {
      _ultimaFalla = lectura;
      state = lectura.gpsApagado ? EstadoGps.gpsApagado : EstadoGps.sinPermiso;
      // Se reintenta solo cada pocos segundos (por si lo enciende sin volver a la app).
      _relojReintento?.cancel();
      _relojReintento = Timer(reintentoGps, reintentar);
      return;
    }
    final punto = lectura.punto;
    if (punto == null) return;
    _ultimaFalla = null;
    state = EstadoGps.enviando;
    ref.read(miUbicacionProvider.notifier).poner(punto);
    _ultimo = punto;
    _hayNuevo = true;
    _enviarSiToca();
  }

  void _enviarSiToca() {
    if (_puedeEnviar && _hayNuevo) unawaited(_enviar());
  }

  Future<void> _enviar() async {
    final punto = _ultimo;
    if (_enviando || punto == null || !ref.mounted) return;
    _enviando = true;
    _hayNuevo = false;
    _puedeEnviar = false;
    _envioDesdeLatido = true;
    _relojEnvio?.cancel();
    _relojEnvio = Timer(minimoEntreEnvios, () {
      _puedeEnviar = true;
      _enviarSiToca(); // si se movió mientras tanto, va la más reciente
    });
    try {
      await ref.read(repartidorRepositoryProvider).enviarUbicacion(punto);
    } on ApiException catch (e) {
      // Ya no lleva el pedido: se vuelve a preguntar y, si no hay ninguno, se deja de enviar.
      if (e.statusCode == 422 && ref.mounted) ref.invalidate(pedidoActualProvider);
      // Sin internet: se manda la más reciente en cuanto se pueda.
      if (e.statusCode == null) _hayNuevo = true;
    } catch (_) {
      _hayNuevo = true;
    } finally {
      _enviando = false;
    }
  }

  void _alLatir() {
    if (!ref.mounted) return;
    if (!_envioDesdeLatido && _ultimo != null) {
      _hayNuevo = true; // quieto: se repite la última para que el cliente vea que sigue
      _enviarSiToca();
    }
    _envioDesdeLatido = false;
  }

  void _parar() {
    _gps?.cancel();
    _relojLatido?.cancel();
    _relojEnvio?.cancel();
    _relojReintento?.cancel();
    _ciclo?.dispose();
    _gps = null;
  }
}

final envioUbicacionProvider = NotifierProvider<EnvioUbicacion, EstadoGps>(EnvioUbicacion.new);
