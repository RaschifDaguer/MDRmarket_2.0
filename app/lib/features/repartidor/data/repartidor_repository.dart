import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/formato/formato.dart';
import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/pagina.dart';
import '../../pedidos/domain/pedido.dart';
import '../domain/pedido_disponible.dart';
import '../domain/repartidor.dart';
import '../domain/tipo_vehiculo.dart';

/// Datos del formulario "Quiero ser repartidor" (el vehículo).
class DatosVehiculo {
  const DatosVehiculo({
    required this.tipoVehiculoId,
    this.placa,
    this.ruat,
    this.marca,
    this.modelo,
    this.color,
    this.anio,
  });

  final int tipoVehiculoId;
  final String? placa;
  final String? ruat;
  final String? marca;
  final String? modelo;
  final String? color;
  final int? anio;
}

/// Registro de repartidor: tipos de vehículo, mi perfil y mi vehículo.
class RepartidorRepository {
  RepartidorRepository(this._dio);

  final Dio _dio;

  Future<List<TipoVehiculo>> tiposVehiculo() => _llamar(() async {
        final r = await _dio.get('/tipos-vehiculo');
        return (r.data as List).map((t) => TipoVehiculo.fromJson(t as Map<String, dynamic>)).toList();
      });

  /// Mi perfil, o null si todavía no me registré como repartidor.
  Future<PerfilRepartidor?> miPerfil() => _llamar(() async {
        try {
          final r = await _dio.get('/repartidor');
          return PerfilRepartidor.fromJson(r.data as Map<String, dynamic>);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) return null;
          rethrow;
        }
      });

  /// Me registro como repartidor (queda en revisión). Si me habían
  /// rechazado, vuelve a enviar la solicitud.
  Future<PerfilRepartidor> solicitar() => _llamar(() async {
        final r = await _dio.post('/repartidor');
        return PerfilRepartidor.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Vehiculo> registrarVehiculo(DatosVehiculo datos) => _llamar(() async {
        String? texto(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
        final r = await _dio.post('/vehiculos', data: {
          'tipo_vehiculo_id': datos.tipoVehiculoId,
          'placa': ?texto(datos.placa),
          'ruat': ?texto(datos.ruat),
          'marca': ?texto(datos.marca),
          'modelo': ?texto(datos.modelo),
          'color': ?texto(datos.color),
          'anio': ?datos.anio,
        });
        return Vehiculo.fromJson(r.data as Map<String, dynamic>);
      });

  // ---------- Vista repartidor (módulo 8) ----------

  /// En línea o desconectado; con la ubicación, si se pudo leer el GPS.
  Future<bool> ponerDisponible(bool disponible, {Coordenada? ubicacion}) => _llamar(() async {
        final r = await _dio.put('/repartidor/disponible', data: {
          'disponible': disponible,
          'latitud': ?ubicacion?.latitud,
          'longitud': ?ubicacion?.longitud,
        });
        return (r.data as Map)['disponible'] == true;
      });

  Future<List<PedidoDisponible>> disponibles() => _llamar(() async {
        final r = await _dio.get('/repartidor/pedidos-disponibles');
        return (r.data as List).map((p) => PedidoDisponible.fromJson(p as Map<String, dynamic>)).toList();
      });

  /// El pedido que lleva ahora, o null.
  Future<Pedido?> pedidoActual() => _llamar(() async {
        final r = await _dio.get('/repartidor/pedido-actual');
        final pedido = (r.data as Map)['pedido'];
        return pedido is Map<String, dynamic> ? Pedido.fromJson(pedido) : null;
      });

  Future<Pedido> aceptar(int pedidoId) => _llamar(() async {
        final r = await _dio.post('/pedidos/$pedidoId/aceptar');
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Pedido> soltar(int pedidoId) => _llamar(() async {
        final r = await _dio.post('/pedidos/$pedidoId/soltar');
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  /// "en_camino" (lo recogió) o "entregado" con el [codigo] (PIN) del cliente.
  Future<Pedido> cambiarEstado(int pedidoId, EstadoPedido estado, {String? codigo}) => _llamar(() async {
        final r = await _dio.put('/repartidor/pedidos/$pedidoId/estado', data: {'estado': estado.api, 'codigo': ?codigo});
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Entregas> entregas() => _llamar(() async {
        final r = await _dio.get('/repartidor/entregas');
        final datos = r.data as Map<String, dynamic>;
        final resumen = (datos['resumen'] as Map?) ?? const {};
        return Entregas(
          pedidos: Pagina.desdeJson(datos, Pedido.fromJson).items,
          total: (resumen['entregas'] as num?)?.toInt() ?? 0,
          totalEnvios: Formato.numero(resumen['total_envios']),
        );
      });

  Future<T> _llamar<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final repartidorRepositoryProvider = Provider<RepartidorRepository>(
  (ref) => RepartidorRepository(ref.watch(dioProvider)),
);

final tiposVehiculoProvider = FutureProvider<List<TipoVehiculo>>(
  (ref) => ref.watch(repartidorRepositoryProvider).tiposVehiculo(),
);

/// Mi perfil de repartidor (null si no lo soy). Invalidar después de registrarme.
final miRepartidorProvider = FutureProvider<PerfilRepartidor?>(
  (ref) => ref.watch(repartidorRepositoryProvider).miPerfil(),
);

/// Pedidos listos que puedo aceptar. Se actualiza al deslizar hacia abajo.
final pedidosDisponiblesProvider = FutureProvider<List<PedidoDisponible>>(
  (ref) => ref.watch(repartidorRepositoryProvider).disponibles(),
);

/// El pedido que llevo ahora (null si ninguno).
final pedidoActualProvider = FutureProvider<Pedido?>(
  (ref) => ref.watch(repartidorRepositoryProvider).pedidoActual(),
);

final entregasProvider = FutureProvider<Entregas>(
  (ref) => ref.watch(repartidorRepositoryProvider).entregas(),
);

/// Lee el GPS una vez (null si no hay permiso o no responde). Las pruebas lo reemplazan.
final ubicacionActualProvider = Provider<Future<Coordenada?> Function()>((ref) => () async {
      try {
        if (!await Geolocator.isLocationServiceEnabled()) return null;
        var permiso = await Geolocator.checkPermission();
        if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) return null;
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
        return Coordenada(p.latitude, p.longitude);
      } catch (_) {
        return null; // sin GPS se conecta igual; los pedidos salen por antigüedad
      }
    });
