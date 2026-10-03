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

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Usuario?>(AuthController.new);
