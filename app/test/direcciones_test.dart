import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/features/pedidos/data/pedidos_repository.dart';

/// Error encontrado en la prueba con Playwright: una dirección guardada sin
/// coordenadas (datos viejos o de ejemplo) rompía toda la sección "¿Dónde lo
/// recibes?" y el cliente no podía terminar su pedido. Sin internet: API falsa.
void main() {
  test('una dirección sin coordenadas se ignora en vez de romper la lista', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://api.falsa'))
      ..interceptors.add(InterceptorsWrapper(onRequest: (opciones, handler) {
        handler.resolve(Response(requestOptions: opciones, statusCode: 200, data: [
          {'id': 3, 'etiqueta': 'Casa', 'direccion': 'Av. Beni 2345', 'latitud': null, 'longitud': null, 'predeterminada': true},
          {'id': 4, 'etiqueta': 'Trabajo', 'direccion': 'Calle 1', 'latitud': -17.78, 'longitud': -63.18, 'predeterminada': false},
        ]));
      }));

    final direcciones = await PedidosRepository(dio).direcciones();

    expect(direcciones.map((d) => d.id), [4]);
  });
}
