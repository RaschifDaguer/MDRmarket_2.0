import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivo_elegido.dart';
import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/negocio.dart';

/// Datos del formulario "Registrar mi negocio".
class DatosNegocio {
  const DatosNegocio({
    required this.nombre,
    required this.categoriaId,
    required this.direccion,
    required this.ubicacion,
    this.descripcion,
    this.telefono,
    this.referencia,
    this.nit,
    this.razonSocial,
  });

  final String nombre;
  final int categoriaId;
  final String direccion;
  final Coordenada ubicacion;
  final String? descripcion;
  final String? telefono;
  final String? referencia;
  final String? nit;
  final String? razonSocial;
}

class NegocioRepository {
  NegocioRepository(this._dio);

  final Dio _dio;

  Future<List<Negocio>> misNegocios() async {
    try {
      final r = await _dio.get('/negocios');
      return (r.data as List).map((n) => Negocio.fromJson(n as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }

  /// Registra el negocio con su foto. Queda "en revisión".
  Future<Negocio> crear(DatosNegocio datos, ArchivoElegido foto) async {
    String? texto(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    try {
      final r = await _dio.post(
        '/negocios',
        data: FormData.fromMap({
          'nombre': datos.nombre.trim(),
          'categoria_id': datos.categoriaId,
          'direccion': datos.direccion.trim(),
          'latitud': datos.ubicacion.latitud,
          'longitud': datos.ubicacion.longitud,
          'descripcion': ?texto(datos.descripcion),
          'telefono': ?texto(datos.telefono),
          'referencia': ?texto(datos.referencia),
          'nit': ?texto(datos.nit),
          'razon_social': ?texto(datos.razonSocial),
          'foto': MultipartFile.fromBytes(foto.bytes, filename: foto.nombre),
        }),
      );
      return Negocio.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final negocioRepositoryProvider = Provider<NegocioRepository>(
  (ref) => NegocioRepository(ref.watch(dioProvider)),
);

/// Negocios del usuario conectado. Invalidar después de registrar uno.
final misNegociosProvider = FutureProvider<List<Negocio>>(
  (ref) => ref.watch(negocioRepositoryProvider).misNegocios(),
);
