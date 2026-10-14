import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/app.dart';
import 'package:mdrmarket/features/carrito/presentation/carrito_controller.dart';
import 'package:mdrmarket/features/catalogo/presentation/catalogo_view.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/pedidos/presentation/pedido_screen.dart';

import 'falsos.dart';

/// Pantallas del cliente con datos falsos (sin internet).
void main() {
  /// La app completa (con su navegación), con la sesión de un cliente.
  Future<void> abrirApp(WidgetTester tester, List overrides) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null, overrides: overrides.cast(), child: const MdrMarketApp()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('el catálogo muestra productos, ofertas y filtra por categoría', (tester) async {
    final catalogo = CatalogoFalso();
    // En tablet: entran todas las categorías y la grilla tiene varias columnas.
    await abrirConFalsos(tester, const CatalogoView(),
        overrides: overridesFalsos(usuario: cliente, catalogo: catalogo), tamano: const Size(1024, 900));

    expect(find.text('Pollo a la broaster'), findsOneWidget);
    expect(find.text('Jarabe para la tos'), findsOneWidget);
    expect(find.text('-20%'), findsOneWidget); // etiqueta de oferta
    expect(find.text('Bs 28,00'), findsOneWidget); // precio con oferta
    expect(find.text('Bs 35,00'), findsOneWidget); // precio normal tachado

    await tester.tap(find.text('Salud y Belleza'));
    await esperar(tester);
    expect(catalogo.consultas.last.categoria, 2);
    expect(find.text('Pollo a la broaster'), findsNothing);
    expect(find.text('Jarabe para la tos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comprar: producto → carrito → confirmar → ver el pedido con su PIN', (tester) async {
    final pedidos = PedidosFalso();
    await abrirApp(tester, overridesFalsos(usuario: cliente, pedidos: pedidos));

    // 1. Catálogo → detalle del producto.
    await tester.tap(find.byKey(const Key('producto-10')));
    await esperar(tester);
    expect(find.text('¡Riquísimo!'), findsOneWidget); // reseña
    await tester.tap(find.byKey(const Key('cantidad-mas')));
    await tester.pump();
    expect(find.textContaining('Agregar · Bs 56,00'), findsOneWidget); // 2 × 28

    await tester.tap(find.textContaining('Agregar · '));
    await esperar(tester);
    expect(find.text('Tienes 2 en el carrito'), findsOneWidget);

    // 2. Volver: aparece la barra del carrito (se espera a que se vaya el aviso "Agregaste…").
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(seconds: 6));
    await esperar(tester);
    expect(find.byKey(const Key('barra-carrito')), findsOneWidget);
    await tester.tap(find.byKey(const Key('barra-carrito')));
    await esperar(tester);

    // 3. Carrito → confirmar.
    expect(find.text('Tu carrito'), findsOneWidget);
    await tester.tap(find.textContaining('Continuar'));
    await esperar(tester);
    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(find.text('Bs 5,00'), findsOneWidget); // envío cotizado a la dirección "Casa"

    await tester.tap(find.textContaining('Hacer pedido'));
    await esperar(tester);

    expect(pedidos.creado!.destino.direccionId, 1);
    expect(pedidos.creado!.metodoPago, 'efectivo');
    expect(pedidos.creado!.carrito.items.single.cantidad, 2);

    // 4. Se abre el pedido con el PIN y el carrito quedó vacío.
    expect(find.byKey(const Key('pin-entrega')), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(PedidoScreen)));
    expect(contenedor.read(carritoProvider), isNull);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('el carrito es de un solo negocio', (tester) async {
    final contenedor = ProviderContainer(overrides: overridesFalsos(usuario: cliente).cast());
    addTearDown(contenedor.dispose);
    final carrito = contenedor.read(carritoProvider.notifier);

    expect(carrito.agregar(pollo, 2), isTrue);
    expect(carrito.agregar(papas, 1), isTrue); // mismo negocio
    expect(carrito.agregar(jarabe, 1), isFalse); // otro negocio: hay que preguntar
    expect(contenedor.read(carritoProvider)!.unidades, 3);

    carrito.agregar(pollo, 50); // no pasa del stock (8)
    expect(contenedor.read(carritoProvider)!.cantidadDe(pollo.id), 8);

    carrito.reemplazarCon(jarabe, 1);
    expect(contenedor.read(carritoProvider)!.negocio.nombre, 'Farmacia Central');
    carrito.cambiarCantidad(jarabe.id, 0);
    expect(contenedor.read(carritoProvider), isNull);
  });

  testWidgets('cancelar un pedido pendiente', (tester) async {
    final pedidos = PedidosFalso(pedidoActual: pedidoDeEjemplo(acciones: const [EstadoPedido.cancelado]));
    await abrirConFalsos(tester, const PedidoScreen(pedidoId: 42), overrides: overridesFalsos(usuario: cliente, pedidos: pedidos));

    expect(find.text('4821'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('cancelar-pedido')), 300,
        scrollable: find.descendant(of: find.byType(PedidoScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const Key('cancelar-pedido')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sí, cancelar'));
    await esperar(tester);

    expect(pedidos.cancelados, 1);
    expect(find.textContaining('Pedido cancelado'), findsOneWidget);
    expect(find.byKey(const Key('cancelar-pedido')), findsNothing);
    await cerrar(tester);
  });

  testWidgets('un pedido entregado se puede calificar', (tester) async {
    final pedidos = PedidosFalso(pedidoActual: pedidoDeEjemplo(estado: EstadoPedido.entregado));
    await abrirConFalsos(tester, const PedidoScreen(pedidoId: 42), overrides: overridesFalsos(usuario: cliente, pedidos: pedidos));

    expect(find.byKey(const Key('calificar-negocio')), findsOneWidget);
    expect(find.text('Calificar producto'), findsNWidgets(2));
    expect(find.byKey(const Key('pin-entrega')), findsNothing); // ya no hace falta el PIN
    await cerrar(tester);
  });
}
