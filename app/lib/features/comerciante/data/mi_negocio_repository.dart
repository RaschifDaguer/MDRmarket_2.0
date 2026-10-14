import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivo_elegido.dart';
import '../../../core/formato/formato.dart';
import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/pagina.dart';
import '../../catalogo/domain/resena.dart';
import '../../pedidos/domain/pedido.dart';
import '../domain/finanzas.dart';
import '../domain/horario.dart';
import '../domain/mi_producto.dart';
import '../domain/negocio.dart';
import 'negocio_repository.dart';

/// Formulario de producto (crear o editar).
class DatosProducto {
  const DatosProducto({
    required this.nombre,
    required this.categoriaId,
    required this.precio,
    this.descripcion,
    this.costo,
    this.precioOferta,
    this.ofertaFin,
    this.stock,
    this.disponible = true,
    this.tamano = 1,
  });

  final String nombre;
  final int categoriaId;
  final double precio;
  final String? descripcion;
  final double? costo;
  final double? precioOferta;
  final DateTime? ofertaFin;

  /// null = sin control de stock.
  final int? stock;
  final bool disponible;

  /// Vehículo mínimo: 1 moto, 2 auto, 3 camión.
  final int tamano;
}

/// Perfil del negocio (editar).
class DatosPerfil {
  const DatosPerfil({
    required this.nombre,
    required this.categoriaId,
    required this.direccion,
    required this.ubicacion,
    this.descripcion,
    this.telefono,
    this.referencia,
    this.nit,
    this.razonSocial,
    this.tiempoPreparacionMin,
    this.pedidoMinimo,
  });

  final String nombre;
  final int categoriaId;
  final String direccion;
  final Coordenada ubicacion;
  final String? descripcion;
  final String? telefono;
  final String? referencia;
  final String? nit;
  final String? razonSocial;
  final int? tiempoPreparacionMin;
  final double? pedidoMinimo;
}

/// Todo lo que el comerciante hace con SU negocio (/api/negocios/{id}/…).
class MiNegocioRepository {
  MiNegocioRepository(this._dio);

  final Dio _dio;

  // ----- Perfil -----

  Future<Negocio> actualizarPerfil(int negocioId, DatosPerfil datos, {ArchivoElegido? foto}) => _llamar(() async {
        final r = await _dio.post('/negocios/$negocioId', data: FormData.fromMap({
          'nombre': datos.nombre.trim(),
          'categoria_id': datos.categoriaId,
          'direccion': datos.direccion.trim(),
          'latitud': datos.ubicacion.latitud,
          'longitud': datos.ubicacion.longitud,
          'descripcion': datos.descripcion?.trim() ?? '',
          'telefono': datos.telefono?.trim() ?? '',
          'referencia': datos.referencia?.trim() ?? '',
          'nit': datos.nit?.trim() ?? '',
          'razon_social': datos.razonSocial?.trim() ?? '',
          'tiempo_preparacion_min': datos.tiempoPreparacionMin?.toString() ?? '',
          'pedido_minimo': datos.pedidoMinimo?.toString() ?? '',
          if (foto != null) 'foto': MultipartFile.fromBytes(foto.bytes, filename: foto.nombre),
        }));
        return Negocio.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Negocio> abierto(int negocioId, bool abierto) => _llamar(() async {
        final r = await _dio.patch('/negocios/$negocioId/abierto', data: {'abierto': abierto});
        return Negocio.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Negocio> horario(int negocioId, List<Horario> horarios) => _llamar(() async {
        final r = await _dio.put('/negocios/$negocioId/horario', data: {
          'horarios': horarios.map((h) => h.toJson()).toList(),
        });
        return Negocio.fromJson(r.data as Map<String, dynamic>);
      });

  Future<ResumenNegocio> resumen(int negocioId) => _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/resumen');
        return ResumenNegocio.fromJson(r.data as Map<String, dynamic>);
      });

  // ----- Productos -----

  Future<List<MiProducto>> productos(int negocioId) => _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/productos');
        return (r.data as List).map((p) => MiProducto.fromJson(p as Map<String, dynamic>)).toList();
      });

  /// Crea (sin [productoId]) o edita un producto. La foto es opcional.
  Future<MiProducto> guardarProducto(int negocioId, DatosProducto datos, {int? productoId, ArchivoElegido? foto}) =>
      _llamar(() async {
        String numero(double? v) => v == null ? '' : v.toStringAsFixed(2);
        final ruta = '/negocios/$negocioId/productos${productoId == null ? '' : '/$productoId'}';
        final r = await _dio.post(ruta, data: FormData.fromMap({
          'nombre': datos.nombre.trim(),
          'categoria_id': datos.categoriaId,
          'descripcion': datos.descripcion?.trim() ?? '',
          'precio': numero(datos.precio),
          'costo': numero(datos.costo),
          'precio_oferta': numero(datos.precioOferta),
          'oferta_fin': datos.ofertaFin == null ? '' : '${Formato.fechaApi(datos.ofertaFin!)} 23:59:59',
          // Laravel acepta 1/0 como booleano (no "true"/"false").
          'controlar_stock': datos.stock == null ? '0' : '1',
          'stock': datos.stock?.toString() ?? '',
          'disponible': datos.disponible ? '1' : '0',
          'categoria_vehiculo_id': datos.tamano,
          if (foto != null) 'foto': MultipartFile.fromBytes(foto.bytes, filename: foto.nombre),
        }));
        return MiProducto.fromJson(r.data as Map<String, dynamic>);
      });

  Future<MiProducto> disponible(int negocioId, int productoId, bool disponible) => _llamar(() async {
        final r = await _dio.patch('/negocios/$negocioId/productos/$productoId/disponible', data: {'disponible': disponible});
        return MiProducto.fromJson(r.data as Map<String, dynamic>);
      });

  Future<void> borrarProducto(int negocioId, int productoId) =>
      _llamar(() => _dio.delete('/negocios/$negocioId/productos/$productoId'));

  // ----- Pedidos que llegan -----

  /// grupo: nuevos · en_curso · terminados
  Future<Pagina<Pedido>> pedidos(int negocioId, String grupo, {int pagina = 1}) => _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/pedidos', queryParameters: {'grupo': grupo, 'page': pagina});
        return Pagina.desdeJson(r.data as Map<String, dynamic>, Pedido.fromJson);
      });

  Future<Pedido> pedido(int negocioId, int pedidoId) => _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/pedidos/$pedidoId');
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  /// Para "entregado" hace falta el [codigo] (PIN del cliente); para rechazar o cancelar, el [motivo].
  Future<Pedido> cambiarEstado(int negocioId, int pedidoId, EstadoPedido estado, {String? motivo, String? codigo}) =>
      _llamar(() async {
        final r = await _dio.put('/negocios/$negocioId/pedidos/$pedidoId/estado', data: {
          'estado': estado.api,
          'motivo': ?motivo,
          'codigo': ?codigo,
        });
        return Pedido.fromJson(r.data as Map<String, dynamic>);
      });

  // ----- Compras y gastos -----

  Future<Pagina<Registro>> registros(int negocioId, {String? tipo, int pagina = 1}) => _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/registros', queryParameters: {'tipo': ?tipo, 'page': pagina});
        return Pagina.desdeJson(r.data as Map<String, dynamic>, Registro.fromJson);
      });

  Future<Registro> registrarCompra(int negocioId,
          {required int productoId, required int cantidad, required double costoUnitario, String? proveedor, DateTime? fecha}) =>
      _llamar(() async {
        final r = await _dio.post('/negocios/$negocioId/registros', data: {
          'tipo': 'compra',
          'producto_id': productoId,
          'cantidad': cantidad,
          'costo_unitario': costoUnitario,
          if (proveedor != null && proveedor.trim().isNotEmpty) 'proveedor': proveedor.trim(),
          if (fecha != null) 'fecha': Formato.fechaApi(fecha),
        });
        return Registro.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Registro> registrarGasto(int negocioId, {required String descripcion, required double monto, DateTime? fecha}) =>
      _llamar(() async {
        final r = await _dio.post('/negocios/$negocioId/registros', data: {
          'tipo': 'gasto',
          'descripcion': descripcion.trim(),
          'monto': monto,
          if (fecha != null) 'fecha': Formato.fechaApi(fecha),
        });
        return Registro.fromJson(r.data as Map<String, dynamic>);
      });

  Future<void> borrarRegistro(int negocioId, int registroId) =>
      _llamar(() => _dio.delete('/negocios/$negocioId/registros/$registroId'));

  // ----- Ganancias -----

  /// agrupar: dia · semana · mes · anio
  Future<Reporte> reporte(int negocioId, DateTime desde, DateTime hasta, String agrupar) => _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/reporte', queryParameters: {
          'desde': Formato.fechaApi(desde),
          'hasta': Formato.fechaApi(hasta),
          'agrupar': agrupar,
        });
        return Reporte.fromJson(r.data as Map<String, dynamic>);
      });

  Future<List<ReporteProducto>> reporteProductos(int negocioId, DateTime desde, DateTime hasta) => _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/reporte-productos', queryParameters: {
          'desde': Formato.fechaApi(desde),
          'hasta': Formato.fechaApi(hasta),
        });
        return (r.data as List).map((p) => ReporteProducto.fromJson(p as Map<String, dynamic>)).toList();
      });

  // ----- Calificaciones -----

  Future<({Calificaciones resumen, Pagina<Resena> resenas})> resenas(int negocioId, {int pagina = 1}) =>
      _llamar(() async {
        final r = await _dio.get('/negocios/$negocioId/resenas', queryParameters: {'page': pagina});
        final json = r.data as Map<String, dynamic>;
        final porEstrellas = (json['por_estrellas'] as Map).map((k, v) => MapEntry(int.parse('$k'), (v as num).toInt()));
        return (
          resumen: Calificaciones(
            rating: (json['rating_promedio'] as num?)?.toDouble(),
            total: (json['total_resenas'] as num?)?.toInt() ?? 0,
            porEstrellas: porEstrellas,
          ),
          resenas: Pagina.desdeJson(json, Resena.fromJson),
        );
      });

  Future<Resena> responder(int negocioId, int resenaId, String respuesta) => _llamar(() async {
        final r = await _dio.put('/negocios/$negocioId/resenas/$resenaId/respuesta', data: {'respuesta': respuesta});
        return Resena.fromJson(r.data as Map<String, dynamic>);
      });

  Future<T> _llamar<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

final miNegocioRepositoryProvider = Provider<MiNegocioRepository>(
  (ref) => MiNegocioRepository(ref.watch(dioProvider)),
);

/// El negocio con el que trabaja la vista comerciante (por ahora, el primero).
final negocioActualProvider = FutureProvider<Negocio?>((ref) async {
  final negocios = await ref.watch(misNegociosProvider.future);
  return negocios.firstOrNull;
});

final resumenNegocioProvider = FutureProvider.family<ResumenNegocio, int>(
  (ref, negocioId) => ref.watch(miNegocioRepositoryProvider).resumen(negocioId),
);

final misProductosProvider = FutureProvider.family<List<MiProducto>, int>(
  (ref, negocioId) => ref.watch(miNegocioRepositoryProvider).productos(negocioId),
);

/// Pedidos del negocio por grupo (nuevos · en_curso · terminados).
final pedidosNegocioProvider = FutureProvider.family<Pagina<Pedido>, ({int negocioId, String grupo})>(
  (ref, filtro) => ref.watch(miNegocioRepositoryProvider).pedidos(filtro.negocioId, filtro.grupo),
);

final pedidoNegocioProvider = FutureProvider.family<Pedido, ({int negocioId, int pedidoId})>(
  (ref, id) => ref.watch(miNegocioRepositoryProvider).pedido(id.negocioId, id.pedidoId),
);
