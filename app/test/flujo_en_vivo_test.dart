import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/archivos/archivo_elegido.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/storage/token_storage.dart';
import 'package:mdrmarket/features/auth/data/auth_repository.dart';
import 'package:mdrmarket/features/carrito/domain/carrito.dart';
import 'package:mdrmarket/features/catalogo/data/catalogo_repository.dart';
import 'package:mdrmarket/features/comerciante/data/mi_negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/data/negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/domain/horario.dart';
import 'package:mdrmarket/features/pedidos/data/pedidos_repository.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';

/// Recorre la app contra la API real (debe estar encendida), para comprobar
/// que la app entiende todas sus respuestas:
///   flutter test test/flujo_en_vivo_test.dart --dart-define=API_URL=http://127.0.0.1:8001/api
/// Crea datos de prueba: usarla solo con la base local.
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

final _foto = ArchivoElegido(
  bytes: base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='),
  nombre: 'foto.png',
);

void main() {
  test('cliente compra y cancela; comerciante carga productos, compras y ve sus números', () async {
    final contenedor = ProviderContainer(overrides: [tokenStorageProvider.overrideWithValue(_TokenEnMemoria())]);
    addTearDown(contenedor.dispose);
    final marca = DateTime.now().millisecondsSinceEpoch;
    await contenedor.read(authRepositoryProvider).registro(DatosRegistro(
          nombre: 'Prueba',
          apellido: 'En Vivo',
          email: 'app.flujo.$marca@mdrmarket.local',
          password: 'Secreta123',
          passwordConfirmacion: 'Secreta123',
          ciNumero: '${marca % 100000000}',
        ));

    // ---------- Cliente ----------
    final catalogo = contenedor.read(catalogoRepositoryProvider);
    final pagina = await catalogo.productos((categoria: null, negocio: 4, texto: null, soloOfertas: false, orden: 'precio'));
    expect(pagina.items, isNotEmpty);
    final producto = pagina.items.first;
    expect(producto.negocio.id, 4);

    final detalle = await catalogo.producto(producto.id);
    expect(detalle.producto.nombre, producto.nombre);
    final tienda = await catalogo.tienda(4);
    expect(tienda.productos, isNotEmpty);
    expect((await catalogo.tiendas()).items, isNotEmpty);

    final pedidos = contenedor.read(pedidosRepositoryProvider);
    final casa = await pedidos.guardarDireccion(
      etiqueta: 'Casa', direccion: 'Calle de prueba 1', ubicacion: const Coordenada(-17.7895, -63.1803),
    );
    expect(casa.predeterminada, isTrue);
    final cotizacion = await pedidos.cotizar(4, casa.ubicacion, [producto.id]);
    expect(cotizacion.costoEnvio, greaterThan(0));

    final carrito = Carrito(negocio: producto.negocio, items: [ItemCarrito(producto: producto, cantidad: 2, notas: 'Prueba')]);
    final pedido = await pedidos.crear(carrito, (direccionId: casa.id, direccion: null, referencia: null, ubicacion: null),
        metodoPago: 'qr', notas: 'Tocar el timbre');
    expect(pedido.estado, EstadoPedido.pendiente);
    expect(pedido.codigoEntrega, matches(RegExp(r'^\d{4}$')));
    expect(pedido.subtotal, closeTo(producto.precioFinal * 2, 0.001));
    expect(pedido.total, closeTo(pedido.subtotal + pedido.costoEnvio + pedido.tarifaServicio, 0.001));
    expect(pedido.items.single.notas, 'Prueba');
    expect(pedido.acciones, [EstadoPedido.cancelado]);

    expect((await pedidos.misPedidos()).items.first.id, pedido.id);
    final cancelado = await pedidos.cancelar(pedido.id, motivo: 'Prueba en vivo');
    expect(cancelado.estado, EstadoPedido.cancelado);
    expect(cancelado.historial.map((h) => h.estado), [EstadoPedido.pendiente, EstadoPedido.cancelado]);

    await expectLater(
      pedidos.calificar(negocioId: 4, estrellas: 5),
      throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', contains('después de recibir'))),
    );

    // ---------- Comerciante (su negocio queda "en revisión") ----------
    final negocio = await contenedor.read(negocioRepositoryProvider).crear(
          const DatosNegocio(nombre: 'Negocio en vivo', categoriaId: 1, direccion: 'Av. Busch 1', ubicacion: Coordenada(-17.7745, -63.1935)),
          _foto,
        );
    final miNegocio = contenedor.read(miNegocioRepositoryProvider);

    final hamburguesa = await miNegocio.guardarProducto(
      negocio.id,
      DatosProducto(nombre: 'Hamburguesa', categoriaId: 101, precio: 30, costo: 18, stock: 5, precioOferta: 25,
          ofertaFin: DateTime.now().add(const Duration(days: 3))),
      foto: _foto,
    );
    expect(hamburguesa.enOferta, isTrue);
    expect(hamburguesa.imagenUrl, contains('/archivos/productos/'));

    final editada = await miNegocio.guardarProducto(
      negocio.id,
      const DatosProducto(nombre: 'Hamburguesa doble', categoriaId: 101, precio: 35, tamano: 2),
      productoId: hamburguesa.id,
    );
    expect(editada.nombre, 'Hamburguesa doble');
    expect(editada.stock, isNull); // sin control de stock
    expect(editada.tamano, 2);
    expect((await miNegocio.disponible(negocio.id, editada.id, false)).disponible, isFalse);

    final bebida = await miNegocio.guardarProducto(negocio.id, const DatosProducto(nombre: 'Refresco', categoriaId: 102, precio: 10, stock: 0));
    await miNegocio.registrarCompra(negocio.id, productoId: bebida.id, cantidad: 12, costoUnitario: 6, proveedor: 'Mayorista');
    await miNegocio.registrarGasto(negocio.id, descripcion: 'Bolsas', monto: 20);
    final productos = await miNegocio.productos(negocio.id);
    expect(productos.firstWhere((p) => p.id == bebida.id).stock, 12); // la compra sumó stock

    final registros = await miNegocio.registros(negocio.id);
    expect(registros.items.map((r) => r.tipo), containsAll(['compra', 'gasto']));

    final hoy = DateTime.now();
    final reporte = await miNegocio.reporte(negocio.id, DateTime(hoy.year, hoy.month), hoy, 'dia');
    expect(reporte.totales.gastos, 20);
    expect(reporte.totales.compras, 72);
    expect((await miNegocio.reporteProductos(negocio.id, DateTime(hoy.year, hoy.month), hoy)).single.producto, 'Refresco');

    final resumen = await miNegocio.resumen(negocio.id);
    expect(resumen.productosActivos, 1); // la hamburguesa quedó oculta
    expect(resumen.pedidosNuevos, 0);

    final conHorario = await miNegocio.horario(negocio.id, const [Horario(diaSemana: 1, apertura: '08:00', cierre: '20:00')]);
    expect(conHorario.horarios.single.cierre, '20:00');
    expect((await miNegocio.abierto(negocio.id, false)).abierto, isFalse);
    expect((await miNegocio.pedidos(negocio.id, 'nuevos')).items, isEmpty);
    expect((await miNegocio.resenas(negocio.id)).resumen.total, 0);
  }, skip: _apiUrl.isEmpty ? 'Falta --dart-define=API_URL=…' : null);
}
