import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_exception.dart';
import 'repartidor_repository.dart';

/// Resultado de leer el GPS: el punto, o por qué no se pudo.
class LecturaGps {
  const LecturaGps(this.punto, {this.sinPermiso = false});

  final Coordenada? punto;

  /// No dio permiso de ubicación (o tiene el GPS apagado).
  final bool sinPermiso;
}

/// Lee el GPS una vez. Las pruebas lo reemplazan.
final leerGpsProvider = Provider<Future<LecturaGps> Function()>((ref) => () async {
      try {
        if (!await Geolocator.isLocationServiceEnabled()) return const LecturaGps(null, sinPermiso: true);
        var permiso = await Geolocator.checkPermission();
        if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
          return const LecturaGps(null, sinPermiso: true);
        }
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
        return LecturaGps(Coordenada(p.latitude, p.longitude));
      } catch (_) {
        return const LecturaGps(null); // sin señal por un momento: se intenta en la próxima vuelta
      }
    });

enum EstadoGps { inactivo, enviando, sinPermiso }

/// Mientras el repartidor tiene un pedido activo (aceptado o en camino), manda
/// su GPS cada [intervalo] para que el cliente lo vea moverse en el mapa. Deja
/// de mandarlo solo: al entregar o soltar (ya no hay pedido actual) o si la
/// API responde que ya no lo lleva (ej. lo cancelaron).
class EnvioUbicacion extends Notifier<EstadoGps> {
  /// Entre 5 y 10 s (la API no acepta más de una cada 3 s).
  static const intervalo = Duration(seconds: 7);

  bool _ocupado = false;

  @override
  EstadoGps build() {
    final pedido = ref.watch(pedidoActualProvider).value;
    if (pedido == null) return EstadoGps.inactivo;

    final reloj = Timer.periodic(intervalo, (_) => enviar());
    ref.onDispose(reloj.cancel);
    Future.microtask(enviar); // la primera, enseguida
    return EstadoGps.enviando;
  }

  Future<void> enviar() async {
    if (_ocupado) return;
    _ocupado = true;
    try {
      final lectura = await ref.read(leerGpsProvider)();
      if (!ref.mounted) return;
      if (lectura.sinPermiso) {
        state = EstadoGps.sinPermiso;
        return;
      }
      if (lectura.punto == null) return;
      await ref.read(repartidorRepositoryProvider).enviarUbicacion(lectura.punto!);
      if (ref.mounted) state = EstadoGps.enviando;
    } on ApiException catch (e) {
      // Ya no lleva el pedido: se vuelve a preguntar y, si no hay ninguno, se deja de enviar.
      if (e.statusCode == 422 && ref.mounted) ref.invalidate(pedidoActualProvider);
    } finally {
      _ocupado = false;
    }
  }
}

final envioUbicacionProvider = NotifierProvider<EnvioUbicacion, EstadoGps>(EnvioUbicacion.new);
