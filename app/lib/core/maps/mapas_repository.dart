import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'coordenada.dart';
import 'ruta.dart';

/// La dirección escrita de un punto del mapa (`GET /api/mapas/direccion`).
class DireccionEncontrada {
  const DireccionEncontrada({required this.corta, required this.texto, this.calle, this.barrio, this.ciudad});

  final String? calle;
  final String? barrio;
  final String? ciudad;

  /// Calle y barrio: "Calle Libertad 123, Equipetrol" (para el campo Dirección).
  final String corta;

  /// Con la ciudad: "Calle Libertad 123, Equipetrol, Santa Cruz de la Sierra".
  final String texto;

  factory DireccionEncontrada.fromJson(Map<String, dynamic> j) => DireccionEncontrada(
    calle: j['calle'] as String?,
    barrio: j['barrio'] as String?,
    ciudad: j['ciudad'] as String?,
    corta: (j['corta'] as String?) ?? '',
    texto: (j['texto'] as String?) ?? (j['corta'] as String?) ?? '',
  );
}

/// Para la ruta, el vehículo según su código o nombre: la bicicleta va por su
/// perfil (ciclovías); auto, camioneta y camión, por el de auto; la moto, igual que el auto.
String vehiculoParaRuta(String? codigoONombre) {
  final v = (codigoONombre ?? '').toLowerCase();
  if (v.contains('bici')) return 'bicicleta';
  if (v.contains('auto') || v.contains('camion') || v.contains('camión')) return 'auto';
  return 'moto';
}

/// Ruta por las calles y dirección de un punto. Las calcula la API con los
/// mapas de OpenStreetMap (ver api/app/Support/Mapas).
class MapasRepository {
  MapasRepository(this._dio);

  final Dio _dio;

  /// Ruta en orden por [puntos] (ej. repartidor → tienda → casa).
  /// [vehiculo]: moto, bicicleta o auto.
  Future<Ruta> ruta(List<Coordenada> puntos, {String vehiculo = 'moto'}) => _llamar(() async {
    final r = await _dio.get(
      '/mapas/ruta',
      queryParameters: {
        'puntos': puntos.map((p) => '${p.latitud.toStringAsFixed(6)},${p.longitud.toStringAsFixed(6)}').join(';'),
        'vehiculo': vehiculo,
      },
    );
    return Ruta.fromJson(r.data as Map<String, dynamic>);
  });

  /// Calle, barrio y ciudad del punto (null si no se encontró).
  Future<DireccionEncontrada?> direccion(Coordenada punto) => _llamar(() async {
    final r = await _dio.get(
      '/mapas/direccion',
      queryParameters: {'latitud': punto.latitud.toStringAsFixed(6), 'longitud': punto.longitud.toStringAsFixed(6)},
    );
    final d = DireccionEncontrada.fromJson(r.data as Map<String, dynamic>);
    return d.corta.isEmpty ? null : d;
  });

  Future<T> _llamar<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final mapasRepositoryProvider = Provider<MapasRepository>((ref) => MapasRepository(ref.watch(dioProvider)));
