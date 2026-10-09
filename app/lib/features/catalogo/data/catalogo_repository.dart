import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/categoria.dart';

class CatalogoRepository {
  CatalogoRepository(this._dio);

  final Dio _dio;

  /// Las 12 categorías principales, cada una con sus subcategorías.
  Future<List<Categoria>> categorias() async {
    try {
      final r = await _dio.get('/categorias');
      return (r.data as List).map((c) => Categoria.fromJson(c as Map<String, dynamic>)).toList();
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
