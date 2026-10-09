import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/usuario.dart';

/// Sesión de la app: `null` = nadie conectado.
///
/// Al abrir la app revisa si hay una sesión guardada. Los métodos lanzan
/// [ApiException] cuando la API rechaza algo, para que la pantalla muestre
/// el mensaje; la sesión solo cambia si la operación salió bien.
class AuthController extends AsyncNotifier<Usuario?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<Usuario?> build() => _repo.usuarioActual();

  Future<void> login(String email, String password) async {
    state = AsyncData(await _repo.login(email, password));
  }

  Future<void> registro(DatosRegistro datos) async {
    state = AsyncData(await _repo.registro(datos));
  }

  Future<void> cambiarVista(Vista vista) async {
    state = AsyncData(await _repo.cambiarVista(vista));
  }

  /// Vuelve a pedir los datos del usuario (ej. después de registrar un
  /// negocio, para que aparezca la vista comerciante en el selector).
  Future<void> refrescar() async {
    state = AsyncData(await _repo.usuarioActual());
  }

  /// Reemplaza el usuario por uno ya actualizado (ej. tras editar el perfil).
  void actualizarUsuario(Usuario usuario) => state = AsyncData(usuario);

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Usuario?>(AuthController.new);
