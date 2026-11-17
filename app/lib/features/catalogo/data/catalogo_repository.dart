import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/pagina.dart';
import '../domain/categoria.dart';
import '../domain/producto.dart';
import '../domain/tienda.dart';
import '../../pedidos/data/pedidos_repository.dart';

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
    final r = await _dio.get(
      '/productos',
      queryParameters: {
        'page': pagina,
        'orden': filtro.orden,
        'categoria': ?filtro.categoria,
        'negocio': ?filtro.negocio,
        if (filtro.texto != null && filtro.texto!.trim().isNotEmpty) 'q': filtro.texto!.trim(),
        if (filtro.soloOfertas) 'ofertas': 1,
      },
    );
    return Pagina.desdeJson(r.data as Map<String, dynamic>, Producto.fromJson);
  });

  Future<ProductoDetalle> producto(int id) => _llamar(() async {
    final r = await _dio.get('/productos/$id');
    return ProductoDetalle.fromJson(r.data as Map<String, dynamic>);
  });

  /// Negocios aprobados (abiertos primero), de 20 en 20. Con [ubicacion] del
  /// cliente, cada tienda trae su envío y tiempo estimado; con [cerca], de la
  /// más cercana a la más lejana.
  Future<Pagina<Tienda>> tiendas({
    int? categoria,
    String? texto,
    int pagina = 1,
    Coordenada? ubicacion,
    bool cerca = false,
  }) => _llamar(() async {
    final r = await _dio.get(
      '/tiendas',
      queryParameters: {
        'page': pagina,
        'categoria': ?categoria,
        if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
        'latitud': ?ubicacion?.latitud,
        'longitud': ?ubicacion?.longitud,
        if (cerca && ubicacion != null) 'orden': 'cerca',
      },
    );
    return Pagina.desdeJson(r.data as Map<String, dynamic>, Tienda.fromJson);
  });

  Future<TiendaDetalle> tienda(int id, {Coordenada? ubicacion}) => _llamar(() async {
    final r = await _dio.get(
      '/tiendas/$id',
      queryParameters: {'latitud': ?ubicacion?.latitud, 'longitud': ?ubicacion?.longitud},
    );
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

final catalogoRepositoryProvider = Provider<CatalogoRepository>((ref) => CatalogoRepository(ref.watch(dioProvider)));

/// Categorías principales (con subcategorías). Casi no cambian: se piden una vez.
final categoriasProvider = FutureProvider<List<Categoria>>((ref) => ref.watch(catalogoRepositoryProvider).categorias());

final productoDetalleProvider = FutureProvider.family<ProductoDetalle, int>(
  (ref, id) => ref.watch(catalogoRepositoryProvider).producto(id),
);

final tiendaDetalleProvider = FutureProvider.family<TiendaDetalle, int>((ref, id) async {
  // Con la dirección del cliente, la tienda trae el envío y el tiempo estimado.
  final entrega = await ref.watch(entregaClienteProvider.future);
  return ref.watch(catalogoRepositoryProvider).tienda(id, ubicacion: entrega?.ubicacion);
});

/// Tiendas cerca de la dirección del cliente (Inicio), con envío y tiempo.
final tiendasCercaProvider = FutureProvider<List<Tienda>>((ref) async {
  final entrega = await ref.watch(entregaClienteProvider.future);
  final pagina = await ref
      .watch(catalogoRepositoryProvider)
      .tiendas(ubicacion: entrega?.ubicacion, cerca: entrega != null);
  return pagina.items;
});

/// Ofertas vigentes (Inicio → "Ofertas del día").
final ofertasProvider = FutureProvider<List<Producto>>((ref) async {
  final pagina = await ref.watch(catalogoRepositoryProvider).productos((
    categoria: null,
    negocio: null,
    texto: null,
    soloOfertas: true,
    orden: 'populares',
  ));
  return pagina.items;
});
