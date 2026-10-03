import 'package:dio/dio.dart';

/// Error de la API ya traducido a un mensaje para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.statusCode, this.errores = const {}});

  /// Mensaje general (ej. "Correo o contraseña incorrectos.").
  final String mensaje;
  final int? statusCode;

  /// Errores por campo que manda Laravel (ej. {'email': ['Ya ha sido registrado.']}).
  final Map<String, List<String>> errores;

  bool get esNoAutenticado => statusCode == 401;

  /// Primer error de un campo del formulario, o null.
  String? errorDe(String campo) {
    final lista = errores[campo];
    return (lista == null || lista.isEmpty) ? null : lista.first;
  }

  factory ApiException.desdeDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.');
      case DioExceptionType.connectionError:
        return ApiException('No se pudo conectar con el servidor. Revisa tu conexión.');
      default:
        break;
    }

    final data = e.response?.data;
    final codigo = e.response?.statusCode;
    if (data is Map) {
      final errores = <String, List<String>>{};
      final crudos = data['errors'];
      if (crudos is Map) {
        crudos.forEach((campo, mensajes) {
          if (mensajes is List) {
            errores['$campo'] = mensajes.map((m) => '$m').toList();
          }
        });
      }
      final mensaje = data['message'];
      return ApiException(
        mensaje is String && mensaje.isNotEmpty ? mensaje : 'Ocurrió un error inesperado.',
        statusCode: codigo,
        errores: errores,
      );
    }
    return ApiException('Ocurrió un error inesperado (código ${codigo ?? '?'}).', statusCode: codigo);
  }

  @override
  String toString() => mensaje;
}
