import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
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
