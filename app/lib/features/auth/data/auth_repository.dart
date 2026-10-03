import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/usuario.dart';

/// Datos del formulario de registro.
class DatosRegistro {
  const DatosRegistro({
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.password,
    required this.passwordConfirmacion,
    required this.ciNumero,
    this.ciComplemento,
    this.ciExpedido,
    this.telefono,
  });

  final String nombre;
  final String apellido;
  final String email;
  final String password;
  final String passwordConfirmacion;
  final String ciNumero;
  final String? ciComplemento;
  final String? ciExpedido;
  final String? telefono;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmacion,
        'ci_numero': ciNumero,
        if (ciComplemento != null && ciComplemento!.isNotEmpty) 'ci_complemento': ciComplemento,
        if (ciExpedido != null) 'ci_expedido': ciExpedido,
        if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
        'dispositivo': 'app-flutter',
      };
}

/// Habla con las rutas de cuenta de la API y guarda el token.
class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  Future<Usuario> login(String email, String password) => _conToken(() => _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password, 'dispositivo': 'app-flutter'},
      ));

  Future<Usuario> registro(DatosRegistro datos) =>
      _conToken(() => _dio.post('/auth/registro', data: datos.toJson()));

  /// Usuario de la sesión guardada, o null si no hay sesión (o expiró).
  Future<Usuario?> usuarioActual() async {
    if (await _tokens.leer() == null) return null;
    try {
      final r = await _dio.get('/me');
      return Usuario.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final error = ApiException.desdeDio(e);
      if (error.esNoAutenticado) {
        await _tokens.borrar();
        return null;
      }
      throw error;
    }
  }

  Future<Usuario> cambiarVista(Vista vista) async {
    try {
      final r = await _dio.put('/me/vista', data: {'vista': vista.name});
      return Usuario.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } on DioException {
      // Si falla (sin internet, token ya vencido) igual cerramos la sesión local.
    }
    await _tokens.borrar();
  }

  Future<Usuario> _conToken(Future<Response<dynamic>> Function() peticion) async {
    try {
      final r = await peticion();
      final data = r.data as Map<String, dynamic>;
      await _tokens.guardar(data['token'] as String);
      return Usuario.fromJson(data['usuario'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);
