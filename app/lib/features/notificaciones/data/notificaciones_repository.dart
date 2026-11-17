import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/notificacion.dart';

/// Avisos del usuario: pedido nuevo, en camino, negocio aprobado…
class NotificacionesRepository {
  NotificacionesRepository(this._dio);

  final Dio _dio;

  /// Las más nuevas primero, con cuántas faltan leer.
  Future<({List<Notificacion> items, int noLeidas})> lista() => _llamar(() async {
    final r = await _dio.get('/notificaciones');
    final datos = r.data as Map<String, dynamic>;
    return (
      items: (datos['data'] as List).map((n) => Notificacion.fromJson(n as Map<String, dynamic>)).toList(),
      noLeidas: ((datos['meta'] as Map?)?['no_leidas'] as num?)?.toInt() ?? 0,
    );
  });

  Future<void> leer(int id) => _llamar(() => _dio.post('/notificaciones/$id/leida'));

  Future<void> leerTodas() => _llamar(() => _dio.post('/notificaciones/leidas'));

  Future<T> _llamar<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final notificacionesRepositoryProvider = Provider<NotificacionesRepository>((ref) {
  ref.watch(usuarioSesionProvider); // otra cuenta: sus avisos se vuelven a pedir
  return NotificacionesRepository(ref.watch(dioProvider));
});

final notificacionesProvider = FutureProvider<({List<Notificacion> items, int noLeidas})>(
  (ref) => ref.watch(notificacionesRepositoryProvider).lista(),
);
