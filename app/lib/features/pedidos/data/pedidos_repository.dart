import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/pagina.dart';
import '../../carrito/domain/carrito.dart';
import '../domain/direccion.dart';
import '../domain/pedido.dart';

/// Dónde entregar: una dirección guardada o una nueva (texto + punto en el mapa).
typedef DestinoPedido = ({int? direccionId, String? direccion, String? referencia, Coordenada? ubicacion});

/// Pedidos, direcciones y reseñas del cliente.
class PedidosRepository {
  PedidosRepository(this._dio);

  final Dio _dio;

  Future<Cotizacion> cotizar(int negocioId, Coordenada destino, List<int> productos) => _llamar(() async {
        final r = await _dio.post('/envio/cotizar', data: {
          'negocio_id': negocioId,
          'latitud': destino.latitud,
          'longitud': destino.longitud,
          'productos': productos,
        });
        return Cotizacion.fromJson(r.data as Map<String, dynamic>);
      });

  /// Hace el pedido con lo que hay en el carrito.
  Future<Pedido> crear(Carrito carrito, DestinoPedido destino, {required String metodoPago, String? notas}) =>
      _llamar(() async {
        final r = await _dio.post('/pedidos', data: {
          'negocio_id': carrito.negocio.id,
          'direccion_id': ?destino.direccionId,
          'direccion': ?destino.direccion,
          'referencia': ?destino.referencia,
          'latitud': ?destino.ubicacion?.latitud,
          'longitud': ?destino.ubicacion?.longitud,
          'metodo_pago': metodoPago,
          if (notas != null && notas.trim().isNotEmpty) 'notas': notas.trim(),
          'items': [
            for (final item in carrito.items)
              {
                'producto_id': item.producto.id,
                'cantidad': item.cantidad,
                if (item.notas != null && item.notas!.trim().isNotEmpty) 'notas': item.notas!.trim(),
              },
          ],
        });
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Pagina<Pedido>> misPedidos({int pagina = 1}) => _llamar(() async {
        final r = await _dio.get('/pedidos', queryParameters: {'page': pagina});
        return Pagina.desdeJson(r.data as Map<String, dynamic>, Pedido.fromJson);
      });

  Future<Pedido> pedido(int id) => _llamar(() async {
        final r = await _dio.get('/pedidos/$id');
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Pedido> cancelar(int id, {String? motivo}) => _llamar(() async {
        final r = await _dio.post('/pedidos/$id/cancelar', data: {'motivo': ?motivo});
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  /// Crea o edita la reseña del usuario (una por producto o negocio).
  Future<void> calificar({int? productoId, int? negocioId, required int estrellas, String? comentario}) =>
      _llamar(() async {
        await _dio.put('/resenas', data: {
          'tipo': productoId != null ? 'producto' : 'negocio',
          'producto_id': ?productoId,
          'negocio_id': ?negocioId,
          'estrellas': estrellas,
          if (comentario != null && comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
        });
      });

  // ----- Direcciones -----

  Future<List<Direccion>> direcciones() => _llamar(() async {
        final r = await _dio.get('/direcciones');
        return (r.data as List).map((d) => Direccion.fromJson(d as Map<String, dynamic>)).toList();
      });

  Future<Direccion> guardarDireccion({
    int? id,
    String? etiqueta,
    required String direccion,
    String? referencia,
    required Coordenada ubicacion,
    bool predeterminada = false,
  }) =>
      _llamar(() async {
        final datos = {
          'etiqueta': etiqueta,
          'direccion': direccion,
          'referencia': referencia,
          'latitud': ubicacion.latitud,
          'longitud': ubicacion.longitud,
          'predeterminada': predeterminada,
        };
        final r = id == null ? await _dio.post('/direcciones', data: datos) : await _dio.put('/direcciones/$id', data: datos);
        return Direccion.fromJson(r.data as Map<String, dynamic>);
      });

  Future<void> borrarDireccion(int id) => _llamar(() => _dio.delete('/direcciones/$id'));

  Future<T> _llamar<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final pedidosRepositoryProvider = Provider<PedidosRepository>(
  (ref) => PedidosRepository(ref.watch(dioProvider)),
);

/// Primera página de mis pedidos. Invalidar después de pedir o cancelar.
final misPedidosProvider = FutureProvider<Pagina<Pedido>>(
  (ref) => ref.watch(pedidosRepositoryProvider).misPedidos(),
);

final pedidoProvider = FutureProvider.family<Pedido, int>(
  (ref, id) => ref.watch(pedidosRepositoryProvider).pedido(id),
);

final direccionesProvider = FutureProvider<List<Direccion>>(
  (ref) => ref.watch(pedidosRepositoryProvider).direcciones(),
);
