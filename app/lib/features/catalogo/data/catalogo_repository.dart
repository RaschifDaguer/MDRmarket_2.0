import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/pagina.dart';
import '../domain/categoria.dart';
import '../domain/producto.dart';
import '../domain/tienda.dart';

/// Filtros del catálogo. Es un record: dos filtros iguales son el mismo
/// (así Riverpod reutiliza lo ya cargado).
typedef FiltroCatalogo = ({int? categoria, int? negocio, String? texto, bool soloOfertas, String orden});

const filtroInicial = (categoria: null, negocio: null, texto: null, soloOfertas: false, orden: 'populares');

class CatalogoRepository {
  CatalogoRepository(this._dio);

  final Dio _dio;

  /// Las 12 categorías principales, cada una con sus subcategorías.
  Future<List<Categoria>> categorias() => _llamar(() async {
        final r = await _dio.get('/categorias');
        return (r.data as List).map((c) => Categoria.fromJson(c as Map<String, dynamic>)).toList();
      });

  /// Productos del catálogo, de 20 en 20.
  Future<Pagina<Producto>> productos(FiltroCatalogo filtro, {int pagina = 1}) => _llamar(() async {
        final r = await _dio.get('/productos', queryParameters: {
          'page': pagina,
          'orden': filtro.orden,
          'categoria': ?filtro.categoria,
          'negocio': ?filtro.negocio,
          if (filtro.texto != null && filtro.texto!.trim().isNotEmpty) 'q': filtro.texto!.trim(),
          if (filtro.soloOfertas) 'ofertas': 1,
        });
        return Pagina.desdeJson(r.data as Map<String, dynamic>, Producto.fromJson);
      });

  Future<ProductoDetalle> producto(int id) => _llamar(() async {
        final r = await _dio.get('/productos/$id');
        return ProductoDetalle.fromJson(r.data as Map<String, dynamic>);
      });

  /// Negocios aprobados (abiertos primero), de 20 en 20.
  Future<Pagina<Tienda>> tiendas({int? categoria, String? texto, int pagina = 1}) => _llamar(() async {
        final r = await _dio.get('/tiendas', queryParameters: {
          'page': pagina,
          'categoria': ?categoria,
          if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
        });
        return Pagina.desdeJson(r.data as Map<String, dynamic>, Tienda.fromJson);
      });

  Future<TiendaDetalle> tienda(int id) => _llamar(() async {
        final r = await _dio.get('/tiendas/$id');
        return TiendaDetalle.fromJson(r.data as Map<String, dynamic>);
      });

  Future<T> _llamar<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final catalogoRepositoryProvider = Provider<CatalogoRepository>(
  (ref) => CatalogoRepository(ref.watch(dioProvider)),
);

/// Categorías principales (con subcategorías). Casi no cambian: se piden una vez.
final categoriasProvider = FutureProvider<List<Categoria>>(
  (ref) => ref.watch(catalogoRepositoryProvider).categorias(),
);

final productoDetalleProvider = FutureProvider.family<ProductoDetalle, int>(
  (ref, id) => ref.watch(catalogoRepositoryProvider).producto(id),
);

final tiendaDetalleProvider = FutureProvider.family<TiendaDetalle, int>(
  (ref, id) => ref.watch(catalogoRepositoryProvider).tienda(id),
);
