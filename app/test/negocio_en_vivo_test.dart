import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/archivos/archivo_elegido.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/storage/token_storage.dart';
import 'package:mdrmarket/features/auth/data/auth_repository.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/catalogo/data/catalogo_repository.dart';
import 'package:mdrmarket/features/comerciante/data/negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/domain/negocio.dart';
import 'package:mdrmarket/features/perfil/data/perfil_repository.dart';

/// Prueba "Registrar mi negocio" contra la API real (debe estar encendida):
///   flutter test test/negocio_en_vivo_test.dart --dart-define=API_URL=http://127.0.0.1:8001/api
/// Sin ese --dart-define la prueba se salta. Crea un usuario y un negocio de
/// prueba: usarla solo con la base local.
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

/// Imagen PNG de 1×1 píxel (sirve como "foto" de prueba).
final _foto = ArchivoElegido(
  bytes: base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='),
  nombre: 'foto.png',
);

void main() {
  test('cliente registra su negocio, sube el carnet y queda como comerciante', () async {
    final container = ProviderContainer(overrides: [tokenStorageProvider.overrideWithValue(_TokenEnMemoria())]);
    addTearDown(container.dispose);
    final auth = container.read(authRepositoryProvider);
    final negocios = container.read(negocioRepositoryProvider);
    final perfil = container.read(perfilRepositoryProvider);

    final marca = DateTime.now().millisecondsSinceEpoch;
    await auth.registro(DatosRegistro(
      nombre: 'Marta',
      apellido: 'Suárez',
      email: 'app.negocio.$marca@mdrmarket.local',
      password: 'Secreta123',
      passwordConfirmacion: 'Secreta123',
      ciNumero: '${marca % 100000000}',
      ciExpedido: 'SC',
    ));

    // 1. Los rubros vienen de la API (categorías principales).
    final rubros = await container.read(catalogoRepositoryProvider).categorias();
    expect(rubros, isNotEmpty);

    // 2. Cuenta nueva: le falta el negocio y las fotos del carnet.
    final antes = await perfil.faltantes('comerciante');
    expect(antes.map((f) => f.codigo), containsAll(['negocio', 'documento.ci_anverso', 'documento.ci_reverso']));

    final datos = DatosNegocio(
      nombre: 'Tienda Marta',
      categoriaId: rubros.first.id,
      direccion: 'Av. Busch 1234',
      ubicacion: Coordenada.centroSantaCruz,
    );

    // 3. Fuera de Santa Cruz: la API lo rechaza y el error va en "latitud".
    await expectLater(
      negocios.crear(
        DatosNegocio(
          nombre: datos.nombre,
          categoriaId: datos.categoriaId,
          direccion: datos.direccion,
          ubicacion: const Coordenada(-16.5, -68.15), // La Paz
        ),
        _foto,
      ),
      throwsA(isA<ApiException>().having((e) => e.errorDe('latitud'), 'error', contains('cobertura'))),
    );

    // 4. Se registra: queda "en revisión", con su foto.
    final creado = await negocios.crear(datos, _foto);
    expect(creado.estado, EstadoNegocio.pendiente);
    expect(creado.logoUrl, isNotNull);
    expect((await negocios.misNegocios()).single.id, creado.id);

    // 5. Ya tiene la vista comerciante (y el botón para cambiar de vista).
    final usuario = await auth.usuarioActual();
    expect(usuario!.vistas, contains(Vista.comerciante));
    expect(usuario.puedeCambiarVista, isTrue);

    // 6. Sube el carnet y ya no le falta nada.
    await perfil.subirDocumento('ci_anverso', _foto);
    await perfil.subirDocumento('ci_reverso', _foto);
    expect(await perfil.faltantes('comerciante'), isEmpty);
  }, skip: _apiUrl.isEmpty ? 'Falta --dart-define=API_URL=…' : null);
}
