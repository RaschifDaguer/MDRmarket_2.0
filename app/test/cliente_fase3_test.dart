// Pantallas nuevas del cliente (fase 3): pestañas, Inicio, Buscar, Cuenta,
// notificaciones, calificar al repartidor, reportar, volver a pedir, tienda
// con envío y registro en 3 pasos.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/app.dart';
import 'package:mdrmarket/core/storage/preferencias.dart';
import 'package:mdrmarket/features/auth/presentation/registro_screen.dart';
import 'package:mdrmarket/features/carrito/presentation/carrito_controller.dart';
import 'package:mdrmarket/features/catalogo/presentation/buscar_view.dart';
import 'package:mdrmarket/features/catalogo/presentation/tienda_screen.dart';
import 'package:mdrmarket/features/cuenta/presentation/cuenta_view.dart';
import 'package:mdrmarket/features/notificaciones/presentation/notificaciones_screen.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/pedidos/presentation/pedido_screen.dart';

import 'falsos.dart';

void main() {
  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> abrirApp(WidgetTester tester, List overrides) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(retry: (_, _) => null, overrides: overrides.cast(), child: const MdrMarketApp()),
    );
    await esperar(tester);
  }

  testWidgets('barra de abajo: Inicio, Buscar, Pedidos y Cuenta', (tester) async {
    await abrirApp(tester, overridesFalsos(usuario: cliente));

    for (final pestana in ['Inicio', 'Buscar', 'Pedidos', 'Cuenta']) {
      expect(find.widgetWithText(NavigationDestination, pestana), findsOneWidget);
    }
    // Inicio: dónde recibe (dirección "Casa" de prueba) y el saludo.
    expect(find.textContaining('Casa'), findsWidgets);
    expect(find.textContaining('¿qué necesitas hoy?'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Cuenta'));
    await esperar(tester);
    expect(find.text('Mi cuenta'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('cerrar-sesion')), 300);
    expect(find.byKey(const Key('cerrar-sesion')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('Inicio: tiendas cerca con tiempo y envío según la dirección', (tester) async {
    final catalogo = CatalogoFalso();
    await abrirApp(tester, overridesFalsos(usuario: cliente, catalogo: catalogo));

    // Se pidieron con la ubicación de la dirección del cliente.
    expect(catalogo.ubicacionesTiendas, contains(casa.ubicacion));
    expect(find.text('Tiendas cerca de ti'), findsOneWidget);
    expect(find.text('30–40 min · Envío Bs 5,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('Buscar: resultados con resumen y búsquedas recientes', (tester) async {
    final preferencias = PreferenciasEnMemoria();
    await abrirConFalsos(
      tester,
      const BuscarView(),
      overrides: overridesFalsos(usuario: cliente, preferencias: preferencias),
    );

    expect(find.text('¿Qué buscas hoy?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-buscar')), 'pollo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await esperar(tester);

    expect(find.byKey(const Key('resumen-busqueda')), findsOneWidget);
    expect(find.textContaining('3 resultados'), findsOneWidget);
    expect(find.byKey(const Key('resultado-10')), findsOneWidget);
    expect(preferencias.datos['busquedas'], 'pollo');

    // "Abierto ahora" filtra en la lista; al borrar, aparecen las recientes.
    await tester.tap(find.byKey(const Key('filtro-abierto')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('campo-buscar')), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await esperar(tester);
    expect(find.byKey(const Key('reciente-pollo')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('Cuenta: número de pedidos, vistas y tema guardado', (tester) async {
    final preferencias = PreferenciasEnMemoria();
    await abrirConFalsos(
      tester,
      const CuentaView(usuario: cliente),
      overrides: overridesFalsos(usuario: cliente, preferencias: preferencias),
    );

    expect(find.text('¿Tienes un negocio?'), findsOneWidget);
    expect(find.text('Quiero repartir'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('numero-direcciones')), matching: find.text('1')), findsOneWidget);

    await tester.ensureVisible(find.text('Oscuro'));
    await tester.pump();
    await tester.tap(find.text('Oscuro'));
    await tester.pump();
    expect(preferencias.datos['tema'], 'dark');
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(CuentaView)));
    expect(contenedor.read(modoTemaProvider), ThemeMode.dark);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('Notificaciones: sin leer resaltadas, marcar todas', (tester) async {
    final avisos = NotificacionesFalso();
    await abrirConFalsos(
      tester,
      const NotificacionesScreen(),
      overrides: overridesFalsos(usuario: cliente, notificaciones: avisos),
    );

    expect(find.text('Tu pedido va en camino'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsOneWidget); // el punto de "sin leer"
    await tester.tap(find.byKey(const Key('leer-todas')));
    await esperar(tester);
    expect(avisos.avisos.every((a) => a.leida), isTrue);
    expect(find.byKey(const Key('leer-todas')), findsNothing);
    await cerrar(tester);
  });

  testWidgets('pedido entregado: califica al repartidor con etiquetas y reporta un problema', (tester) async {
    final pedidos = PedidosFalso(
      pedidoActual: pedidoDeEjemplo(estado: EstadoPedido.entregado, conRepartidor: true, repartidorId: 7),
    );
    await abrirConFalsos(
      tester,
      const PedidoScreen(pedidoId: 42),
      overrides: overridesFalsos(usuario: cliente, pedidos: pedidos),
    );

    expect(find.byKey(const Key('ya-tienes-tu-pedido')), findsOneWidget);
    expect(find.text('¿Qué tal Diego?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('estrella-repartidor-5')));
    await tester.tap(find.byKey(const Key('etiqueta-Puntual')));
    await tester.tap(find.byKey(const Key('etiqueta-Amable')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('enviar-calificacion-repartidor')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('enviar-calificacion-repartidor')));
    await esperar(tester);
    final calificacion = pedidos.calificacionesRepartidor.single;
    expect((calificacion.repartidorId, calificacion.estrellas), (7, 5));
    expect(calificacion.etiquetas, ['Puntual', 'Amable']);

    // "Hubo un problema" con el repartidor.
    await tester.ensureVisible(find.byKey(const Key('hubo-un-problema')));
    await tester.tap(find.byKey(const Key('hubo-un-problema')));
    await esperar(tester);
    await tester.tap(find.text('El repartidor'));
    await esperar(tester);
    await tester.tap(find.byKey(const Key('motivo-maltrato')));
    await tester.enterText(find.byKey(const Key('reporte-descripcion')), 'Me gritó');
    await tester.pump();
    await tester.tap(find.byKey(const Key('enviar-reporte')));
    await esperar(tester);
    expect(pedidos.reportes.single, (pedidoId: 42, sobre: 'repartidor', motivo: 'maltrato', descripcion: 'Me gritó'));
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('volver a pedir pone los productos en el carrito', (tester) async {
    final pedidos = PedidosFalso(pedidoActual: pedidoDeEjemplo(estado: EstadoPedido.entregado));
    await abrirApp(tester, overridesFalsos(usuario: cliente, pedidos: pedidos));
    await tester.tap(find.widgetWithText(NavigationDestination, 'Pedidos'));
    await esperar(tester);

    await tester.tap(find.byKey(const Key('pedido-42')).last);
    await esperar(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('volver-a-pedir')), 300);
    await tester.tap(find.byKey(const Key('volver-a-pedir')));
    await esperar(tester);

    final contenedor = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final carrito = contenedor.read(carritoProvider)!;
    expect(carrito.negocio.id, 5);
    expect(carrito.cantidadDe(10), 2); // 2 × Pollo a la broaster
    expect(carrito.cantidadDe(11), 1);
    expect(find.text('Tu carrito'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('tienda: tiempo y envío hasta la dirección del cliente', (tester) async {
    await abrirConFalsos(tester, const TiendaScreen(tiendaId: 5), overrides: overridesFalsos(usuario: cliente));
    expect(find.text('Llega en 30–40 min'), findsOneWidget);
    expect(find.text('Envío Bs 5,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('registro en 3 pasos: no avanza sin los datos y vuelve atrás', (tester) async {
    await abrirConFalsos(
      tester,
      const RegistroScreen(),
      overrides: overridesFalsos(usuario: cliente),
      tamano: const Size(390, 1400),
    );

    expect(find.text('Paso 1 de 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('registro-siguiente')));
    await tester.pump();
    expect(find.text('Paso 1 de 3'), findsOneWidget); // faltan nombre y apellido

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Sofía');
    await tester.enterText(find.widgetWithText(TextFormField, 'Apellido'), 'Vargas');
    await tester.tap(find.byKey(const Key('registro-siguiente')));
    await esperar(tester);
    expect(find.text('Paso 2 de 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('registro-atras')));
    await esperar(tester);
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    // Lo escrito se mantiene.
    expect(find.text('Sofía'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });
}
