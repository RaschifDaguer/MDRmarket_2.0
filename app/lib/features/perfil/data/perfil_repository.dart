import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivo_elegido.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/usuario.dart';
import '../domain/faltante.dart';

/// Datos personales, lo que falta para cada rol y subida de documentos.
class PerfilRepository {
  PerfilRepository(this._dio);

  final Dio _dio;

  /// Lo que le falta para usar `rol` ('repartidor' o 'comerciante'). Vacío = completo.
  Future<List<Faltante>> faltantes(String rol) => _llamar(() async {
        final r = await _dio.get('/me/faltantes/$rol');
        return ((r.data as Map)['faltantes'] as List)
            .map((f) => Faltante.fromJson(f as Map<String, dynamic>))
            .toList();
      });

  /// Actualiza datos personales (solo los campos que se pasen).
  Future<Usuario> actualizar(Map<String, dynamic> datos) => _llamar(() async {
        final r = await _dio.put('/me', data: datos);
        return Usuario.fromJson(r.data as Map<String, dynamic>);
      });

  /// Sube la foto de un documento (ej. tipo 'ci_anverso'). Queda "en revisión".
  Future<void> subirDocumento(String tipo, ArchivoElegido archivo, {int? negocioId, int? vehiculoId}) =>
      _llamar(() async {
        await _dio.post(
          '/documentos',
          data: FormData.fromMap({
            'tipo': tipo,
            'archivo': MultipartFile.fromBytes(archivo.bytes, filename: archivo.nombre),
            'negocio_id': ?negocioId,
            'vehiculo_id': ?vehiculoId,
          }),
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

final perfilRepositoryProvider = Provider<PerfilRepository>(
  (ref) => PerfilRepository(ref.watch(dioProvider)),
);

/// Lo que le falta al usuario para un rol. Invalidar después de subir algo.
final faltantesProvider = FutureProvider.family<List<Faltante>, String>(
  (ref, rol) => ref.watch(perfilRepositoryProvider).faltantes(rol),
);
