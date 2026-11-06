import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/network/api_client.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/auth/presentation/auth_controller.dart';
import 'package:mdrmarket/features/pedidos/data/pedidos_repository.dart';
import 'package:mdrmarket/features/repartidor/data/repartidor_repository.dart';

/// Sesión que la prueba puede cambiar (como cerrar sesión y entrar con otra cuenta).
class _SesionCambiable extends AuthController {
  _SesionCambiable(this._inicial);

  final Usuario? _inicial;

  @override
  Future<Usuario?> build() async => _inicial;

  void cambiarA(Usuario? usuario) => state = AsyncData(usuario);
}

Usuario _usuario(int id) => Usuario(id: id, nombre: 'U$id', email: 'u$id@correo.com', vistas: const [Vista.cliente], vistaGuardada: 'cliente');

/// Error encontrado probando a mano: al cerrar sesión y entrar con otra cuenta
/// en la misma pestaña, la app seguía mostrando los pedidos de la anterior
/// (y el pedido nuevo "se perdía"). Los datos de cada persona se vuelven a
/// pedir cuando cambia quién tiene la sesión. Sin internet: la API es falsa.
void main() {
  late int conectado;
  late ProviderContainer contenedor;

  setUp(() {
    conectado = 1;
    // API falsa: cada cuenta tiene un pedido con su mismo número.
    final dio = Dio(BaseOptions(baseUrl: 'http://api.falsa'))
      ..interceptors.add(InterceptorsWrapper(onRequest: (opciones, handler) {
        final datos = switch (opciones.path) {
          '/pedidos' => {
              'data': [
                {'id': conectado, 'estado': 'listo', 'negocio': {'id': 4, 'nombre': 'FarmaSuper'}, 'direccion_entrega': 'Calle 1',
                  'subtotal': '10.00', 'costo_envio': '5.00', 'tarifa_servicio': '0.00', 'total': '15.00', 'metodo_pago': 'efectivo'},
              ],
              'meta': {'current_page': 1, 'last_page': 1},
            },
          '/repartidor' => {'estado_verificacion': 'aprobado', 'disponible': conectado == 1, 'vehiculos': []},
          _ => <String, dynamic>{},
        };
        handler.resolve(Response(requestOptions: opciones, data: datos, statusCode: 200));
      }));

    contenedor = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(() => _SesionCambiable(_usuario(1))),
      dioProvider.overrideWithValue(dio),
    ]);
    addTearDown(contenedor.dispose);
  });

  Future<void> entrarCon(int id) async {
    conectado = id;
    (contenedor.read(authControllerProvider.notifier) as _SesionCambiable).cambiarA(_usuario(id));
    await Future<void>.delayed(Duration.zero);
  }

  test('al cambiar de cuenta, se ven los pedidos de la cuenta nueva', () async {
    await contenedor.read(authControllerProvider.future);
    contenedor.listen(misPedidosProvider, (_, _) {}); // la pantalla abierta

    expect((await contenedor.read(misPedidosProvider.future)).items.map((p) => p.id), [1]);

    await entrarCon(2);
    expect((await contenedor.read(misPedidosProvider.future)).items.map((p) => p.id), [2]);
  });

  test('al cambiar de cuenta, el perfil de repartidor también se vuelve a pedir', () async {
    await contenedor.read(authControllerProvider.future);
    contenedor.listen(miRepartidorProvider, (_, _) {});

    expect((await contenedor.read(miRepartidorProvider.future))!.disponible, isTrue);

    await entrarCon(2);
    expect((await contenedor.read(miRepartidorProvider.future))!.disponible, isFalse);
  });
}
