import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/storage/token_storage.dart';
import 'package:mdrmarket/features/auth/data/auth_repository.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';

/// Prueba la app contra la API real (debe estar encendida). Ejecutar con:
///   flutter test test/api_en_vivo_test.dart --dart-define=API_URL=http://127.0.0.1:8001/api
/// Sin ese --dart-define la prueba se salta.
const _apiUrl = String.fromEnvironment('API_URL');

class _TokenEnMemoria implements TokenStorage {
  String? token;
  @override
  Future<String?> leer() async => token;
  @override
  Future<void> guardar(String t) async => token = t;
  @override
  Future<void> borrar() async => token = null;
}

void main() {
  test('registro, perfil, cambio de vista y cierre de sesión', () async {
    final tokens = _TokenEnMemoria();
    final container = ProviderContainer(overrides: [tokenStorageProvider.overrideWithValue(tokens)]);
    addTearDown(container.dispose);
    final repo = container.read(authRepositoryProvider);

    final email = 'app.modulo3.${DateTime.now().millisecondsSinceEpoch}@mdrmarket.local';

    // 1. Registro: guarda el token y vuelve como cliente, sin botón de cambiar vista.
    final nuevo = await repo.registro(DatosRegistro(
      nombre: 'Lucía',
      apellido: 'Rojas',
      email: email,
      password: 'Secreta123',
      passwordConfirmacion: 'Secreta123',
      ciNumero: '${DateTime.now().millisecondsSinceEpoch % 100000000}',
      ciExpedido: 'SC',
    ));
    expect(tokens.token, isNotNull);
    expect(nuevo.nombreCompleto, 'Lucía Rojas');
    expect(nuevo.vistas, [Vista.cliente]);
    expect(nuevo.puedeCambiarVista, isFalse);

    // 2. Al reabrir la app, la sesión guardada trae al mismo usuario.
    final actual = await repo.usuarioActual();
    expect(actual?.email, email);

    // 3. No puede cambiar a una vista que no tiene.
    await expectLater(
      repo.cambiarVista(Vista.repartidor),
      throwsA(isA<ApiException>().having((e) => e.errorDe('vista'), 'error', 'No tienes acceso a esa vista.')),
    );

    // 4. Contraseña incorrecta: mensaje en español.
    await expectLater(
      repo.login(email, 'Incorrecta1'),
      throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', 'Correo o contraseña incorrectos.')),
    );

    // 5. Cerrar sesión borra el token y la sesión ya no sirve.
    await repo.logout();
    expect(tokens.token, isNull);
    expect(await repo.usuarioActual(), isNull);
  }, skip: _apiUrl.isEmpty ? 'Falta --dart-define=API_URL=…' : null);
}
