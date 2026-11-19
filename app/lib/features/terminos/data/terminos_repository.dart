import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/usuario.dart';

/// Una sección de los términos: título y sus párrafos.
class SeccionTerminos {
  const SeccionTerminos({required this.titulo, required this.parrafos});

  final String titulo;
  final List<String> parrafos;
}

/// Términos y condiciones vigentes (GET /api/terminos).
class Terminos {
  const Terminos({
    required this.version,
    required this.actualizado,
    required this.declaracion,
    required this.resumen,
    required this.secciones,
  });

  final String version;
  final String actualizado;

  /// Lo que se acepta con la casilla: "Declaro que soy mayor de 18 años y acepto…".
  final String declaracion;
  final String resumen;
  final List<SeccionTerminos> secciones;

  factory Terminos.fromJson(Map<String, dynamic> json) => Terminos(
        version: json['version'] as String,
        actualizado: json['actualizado'] as String,
        declaracion: json['declaracion'] as String,
        resumen: json['resumen'] as String,
        secciones: ((json['secciones'] as List?) ?? const [])
            .map((s) => SeccionTerminos(
                  titulo: (s as Map)['titulo'] as String,
                  parrafos: ((s['parrafos'] as List?) ?? const []).cast<String>(),
                ))
            .toList(),
      );
}

class TerminosRepository {
  TerminosRepository(this._dio);

  final Dio _dio;

  Future<Terminos> vigentes() => _llamar(() async {
        final r = await _dio.get('/terminos');
        return Terminos.fromJson(r.data as Map<String, dynamic>);
      });

  /// Cuentas antiguas o términos nuevos: los acepta (y declara ser mayor de 18).
  Future<Usuario> aceptar() => _llamar(() async {
        final r = await _dio.post('/me/terminos', data: {'acepta': true});
        return Usuario.fromJson(r.data as Map<String, dynamic>);
      });

  Future<T> _llamar<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final terminosRepositoryProvider = Provider<TerminosRepository>(
  (ref) => TerminosRepository(ref.watch(dioProvider)),
);

final terminosProvider = FutureProvider<Terminos>((ref) => ref.watch(terminosRepositoryProvider).vigentes());
