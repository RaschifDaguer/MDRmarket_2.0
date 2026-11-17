// App del comercio (fase 4): barra de abajo, pedido nuevo con cuenta
// regresiva, alistar y "Marcar como listo", repartidores cerca, producto con
// fotos y ganancia, ganancias por período y "Más".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/app.dart';
import 'package:mdrmarket/core/widgets/widgets.dart';
import 'package:mdrmarket/features/comerciante/domain/horario.dart';
import 'package:mdrmarket/features/comerciante/domain/mi_producto.dart';
import 'package:mdrmarket/features/comerciante/presentation/pestanas/ganancias_tab.dart';
import 'package:mdrmarket/features/comerciante/presentation/pestanas/mas_tab.dart';
import 'package:mdrmarket/features/comerciante/presentation/producto_form_screen.dart';
import 'package:mdrmarket/features/comerciante/presentation/widgets/cuenta_regresiva.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';

import 'falsos.dart';

void main() {
  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> abrirApp(WidgetTester tester, {MiNegocioFalso? miNegocio}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: overridesFalsos(
          usuario: comerciante,
          negocios: const [negocioAprobado],
          miNegocio: miNegocio,
        ).cast(),
        child: const MdrMarketApp(),
      ),
    );
    await esperar(tester);
  }

  Future<void> abrirPedido(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Pedidos'));
    await esperar(tester);
    await tester.tap(find.byKey(const Key('pedido-negocio-42')));
    await esperar(tester);
  }

  testWidgets('barra de abajo: Resumen, Pedidos, Productos, Ganancias y Más (en ese orden)', (tester) async {
    await abrirApp(tester);
    final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final textos = [for (final d in barra.destinations) (d as NavigationDestination).label];
    expect(textos, ['Resumen', 'Pedidos', 'Productos', 'Ganancias', 'Más']);
    await cerrar(tester);
  });

  testWidgets('pedido nuevo: cuenta regresiva, solo Aceptar o Rechazar; después Empezar a alistar', (tester) async {
    final miNegocio = MiNegocioFalso()
      ..pedidoMostrado = pedidoDeEjemplo(
        paraNegocio: true,
        acciones: const [EstadoPedido.confirmado, EstadoPedido.rechazado],
        aceptarAntes: DateTime.now().add(const Duration(seconds: 45)),
      );
    await abrirApp(tester, miNegocio: miNegocio);
    await abrirPedido(tester);

    expect(find.byKey(const Key('cuenta-regresiva')), findsOneWidget);
    expect(find.textContaining(RegExp(r'Acepta en 0:4\d o se rechaza solo')), findsOneWidget);
    expect(find.byKey(const Key('accion-confirmado')), findsOneWidget);
    expect(find.byKey(const Key('accion-rechazado')), findsOneWidget);
    expect(find.byKey(const Key('accion-preparando')), findsNothing); // "Empezar a alistar" todavía no

    // Corre cada segundo.
    final antes = tester
        .widget<Text>(find.descendant(of: find.byKey(const Key('cuenta-regresiva')), matching: find.byType(Text)))
        .data;
    // El reloj del texto es el real: se deja pasar un poco más de 1 segundo.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 1));
    final despues = tester
        .widget<Text>(find.descendant(of: find.byKey(const Key('cuenta-regresiva')), matching: find.byType(Text)))
        .data;
    expect(despues, isNot(antes));

    await tester.tap(find.byKey(const Key('accion-confirmado')));
    await esperar(tester);
    expect(miNegocio.cambios, [EstadoPedido.confirmado]);
    expect(find.byKey(const Key('cuenta-regresiva')), findsNothing);
    expect(find.byKey(const Key('accion-preparando')), findsOneWidget);
    expect(find.text('Empezar a alistar'), findsOneWidget);
    expect(find.byKey(const Key('accion-rechazado')), findsNothing); // aceptado ya no se rechaza ni cancela
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  test('la cuenta regresiva se escribe en minutos y segundos', () {
    expect(CuentaRegresiva.texto(const Duration(seconds: 45)), '0:45');
    expect(CuentaRegresiva.texto(const Duration(seconds: 125)), '2:05');
    expect(CuentaRegresiva.texto(const Duration(seconds: -3)), '0:00');
  });

  testWidgets('alistar: "Marcar como listo" recién con todos los productos marcados', (tester) async {
    final miNegocio = MiNegocioFalso()
      ..pedidoMostrado = pedidoDeEjemplo(
        paraNegocio: true,
        estado: EstadoPedido.preparando,
        acciones: const [EstadoPedido.listo],
      );
    await abrirApp(tester, miNegocio: miNegocio);
    await abrirPedido(tester);

    expect(find.byKey(const Key('lista-alistar')), findsOneWidget);
    expect(find.text('Alistando · 0 de 2 productos'), findsOneWidget);
    BotonPrincipal listo() => tester.widget<BotonPrincipal>(find.byKey(const Key('accion-listo')));
    expect(listo().onPressed, isNull);
    expect(find.text('Marca todos los productos para dejarlo listo (0 de 2).'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alistar-501')));
    await esperar(tester);
    expect(miNegocio.marcados, [(501, true)]);
    expect(find.text('Alistando · 1 de 2 productos'), findsOneWidget);
    expect(listo().onPressed, isNull);

    await tester.ensureVisible(find.byKey(const Key('alistar-502')));
    await tester.tap(find.byKey(const Key('alistar-502')));
    await esperar(tester);
    expect(miNegocio.marcados, [(501, true), (502, true)]);
    expect(listo().onPressed, isNotNull);
    expect(find.byKey(const Key('falta-alistar')), findsNothing);

    // Desmarcar uno vuelve a bloquearlo.
    await tester.tap(find.byKey(const Key('alistar-501')));
    await esperar(tester);
    expect(listo().onPressed, isNull);
    await tester.tap(find.byKey(const Key('alistar-501')));
    await esperar(tester);

    await tester.tap(find.byKey(const Key('accion-listo')));
    await esperar(tester);
    expect(miNegocio.cambios, [EstadoPedido.listo]);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('listo: "Buscando repartidor…" con cuántos hay cerca, sin la rueda en pruebas (movimiento reducido)', (
    tester,
  ) async {
    final miNegocio = MiNegocioFalso()
      ..pedidoMostrado = pedidoDeEjemplo(paraNegocio: true, estado: EstadoPedido.listo, repartidoresCerca: 3);
    await abrirApp(tester, miNegocio: miNegocio);
    await abrirPedido(tester);

    expect(find.text('Buscando repartidor…'), findsOneWidget);
    expect(find.textContaining('3 repartidores cerca de tu tienda'), findsOneWidget);
    // Movimiento reducido: un ícono quieto, no la rueda que gira.
    final tarjeta = find.byKey(const Key('buscando-repartidor'));
    expect(find.descendant(of: tarjeta, matching: find.byType(CircularProgressIndicator)), findsNothing);
    expect(find.descendant(of: tarjeta, matching: find.byIcon(Icons.search)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('lista de pedidos: productos, cuenta regresiva, Aceptar ahí mismo y quién lo lleva', (tester) async {
    final miNegocio = MiNegocioFalso()
      ..lista = [
        pedidoDeEjemplo(
          paraNegocio: true,
          acciones: const [EstadoPedido.confirmado, EstadoPedido.rechazado],
          aceptarAntes: DateTime.now().add(const Duration(seconds: 50)),
        ),
      ];
    await abrirApp(tester, miNegocio: miNegocio);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Pedidos'));
    await esperar(tester);

    expect(find.text('#42 · Lucía Rojas'), findsOneWidget);
    expect(find.text('2× Pollo a la broaster'), findsOneWidget);
    expect(find.text('1× Papas fritas'), findsOneWidget);
    expect(find.text('Efectivo · 2,4 km'), findsOneWidget);
    expect(find.textContaining('Acepta en 0:'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aceptar-42')));
    await esperar(tester);
    expect(miNegocio.cambios, [EstadoPedido.confirmado]);

    // En camino con repartidor: "Lo lleva Diego Rodríguez".
    miNegocio.lista = [pedidoDeEjemplo(paraNegocio: true, estado: EstadoPedido.enCamino, conRepartidor: true)];
    await tester.tap(find.textContaining('En curso'));
    await esperar(tester);
    expect(find.text('Lo lleva Diego Rodríguez'), findsOneWidget);
    expect(find.byKey(const Key('aceptar-42')), findsNothing);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('nuevo producto: hasta 4 fotos y cuánto gana por cada uno', (tester) async {
    await abrirConFalsos(
      tester,
      const ProductoFormScreen(),
      overrides: overridesFalsos(usuario: comerciante, negocios: const [negocioAprobado]),
      tamano: const Size(390, 1600),
    );

    expect(find.text('Hasta 4 fotos (0 de 4). Con buena luz se vende más.'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('agregar-foto')));
      await tester.pump();
    }
    expect(find.text('Hasta 4 fotos (4 de 4). Con buena luz se vende más.'), findsOneWidget);
    expect(find.byKey(const Key('agregar-foto')), findsNothing); // ya no se pueden más
    expect(find.text('Portada'), findsOneWidget); // la primera
    await tester.tap(find.byKey(const Key('quitar-nueva-3')));
    await tester.pump();
    expect(find.byKey(const Key('agregar-foto')), findsOneWidget);

    // Ganancia: precio − lo que costó.
    expect(find.text('Escribe el precio y lo que te costó para ver cuánto ganas.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-precio')), '240');
    await tester.enterText(find.byKey(const Key('campo-costo')), '170');
    await tester.pump();
    expect(find.text('Ganas Bs 70,00 por cada uno (29 %)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-costo')), '250');
    await tester.pump();
    expect(find.textContaining('Pierdes Bs 10,00'), findsOneWidget);
    expect(find.text('Publicar producto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar producto: sube las fotos nuevas y quita una de las que tenía', (tester) async {
    final miNegocio = MiNegocioFalso();
    const producto = MiProducto(
      id: 10,
      nombre: 'Pollo a la broaster',
      precio: 35,
      costo: 20,
      stock: 8,
      categoriaId: 101,
      imagenes: [
        FotoProducto(id: 1, url: 'https://mdrmarket.test/a.png', portada: true),
        FotoProducto(id: 2, url: 'https://mdrmarket.test/b.png'),
      ],
    );
    await abrirConFalsos(
      tester,
      const ProductoFormScreen(producto: producto),
      overrides: overridesFalsos(usuario: comerciante, negocios: const [negocioAprobado], miNegocio: miNegocio),
      tamano: const Size(390, 1600),
    );
    await esperar(tester);

    expect(find.byKey(const Key('foto-subida-1')), findsOneWidget);
    expect(find.text('Ganas Bs 15,00 por cada uno (43 %)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quitar-foto-1')));
    await esperar(tester);
    expect(miNegocio.fotosBorradas, [1]);
    expect(find.byKey(const Key('foto-subida-1')), findsNothing);

    await tester.tap(find.byKey(const Key('agregar-foto')));
    await tester.pump();
    await tester.tap(find.text('Guardar cambios'));
    await esperar(tester);
    expect(miNegocio.guardados.single.$2, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ganancias: Hoy, Semana y Mes, comparadas con el período anterior', (tester) async {
    await abrirApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Ganancias'));
    await esperar(tester);

    for (final p in ['Hoy', 'Semana', 'Mes']) {
      expect(find.descendant(of: find.byKey(const Key('periodo-ganancias')), matching: find.text(p)), findsOneWidget);
    }
    // El falso da la misma ganancia siempre: 0 % de diferencia.
    expect(find.text('+0 % que ayer'), findsOneWidget);
    await tester.tap(find.text('Semana'));
    await esperar(tester);
    expect(find.text('+0 % que la semana pasada'), findsOneWidget);
    await tester.tap(find.text('Mes'));
    await esperar(tester);
    expect(find.text('+0 % que el mes pasado'), findsOneWidget);

    // Lo más vendido primero.
    final scroll = find.descendant(of: find.byType(GananciasTab), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('mas-vendidos')), 300, scrollable: scroll);
    final papas = tester.getTopLeft(find.byKey(const Key('vendido-11')));
    final pollo = tester.getTopLeft(find.byKey(const Key('vendido-10')));
    expect(papas.dy < pollo.dy, isTrue);
    expect(find.text('25 vendidos · ganaste Bs 90,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  test('períodos de ganancias y el anterior para comparar', () {
    final hoy = DateTime(2026, 3, 31, 15);
    expect(Periodo.hoy.anterior(hoy), (DateTime(2026, 3, 30), DateTime(2026, 3, 30)));
    expect(Periodo.semana.rango(hoy), (DateTime(2026, 3, 25), DateTime(2026, 3, 31)));
    expect(Periodo.semana.anterior(hoy), (DateTime(2026, 3, 18), DateTime(2026, 3, 24)));
    // Del 1 al 31 de marzo contra febrero completo (tiene 28 días).
    expect(Periodo.mes.anterior(hoy), (DateTime(2026, 2), DateTime(2026, 2, 28)));
  });

  testWidgets('Más: aviso de entregas, horario, calificaciones y documentos', (tester) async {
    await abrirApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Más'));
    await esperar(tester);

    expect(find.byKey(const Key('aviso-entregas')), findsOneWidget);
    expect(find.text('Lun · 08:00 a 20:00'), findsOneWidget);
    expect(find.text('★ 4.5 · 3 opiniones'), findsOneWidget);
    expect(find.text('1 rechazado: revísalo'), findsOneWidget);
    expect(find.text('Cambiar a vista cliente'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('mas-/negocio/documentos')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mas-/negocio/documentos')));
    await esperar(tester);
    expect(find.text('Del negocio'), findsOneWidget);
    expect(find.text('Verificado'), findsOneWidget);
    expect(find.text('Rechazado · La foto está borrosa'), findsOneWidget);
    expect(find.byKey(const Key('resubir-2')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('En revisión'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Tuyos'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  test('horario en una línea', () {
    Horario h(int d, [String a = '08:00:00', String c = '22:00:00']) => Horario(diaSemana: d, apertura: a, cierre: c);
    expect(MasTab.resumenHorario(const []), 'Todavía no cargaste tu horario');
    expect(MasTab.resumenHorario([for (var d = 1; d <= 6; d++) h(d)]), 'Lun a sáb · 08:00 a 22:00');
    expect(MasTab.resumenHorario([for (var d = 1; d <= 7; d++) h(d)]), 'Todos los días · 08:00 a 22:00');
    expect(
      MasTab.resumenHorario([h(1), h(3), h(5), h(6, '09:00', '13:00')]),
      'Lun, mié, vie · 08:00 a 22:00 (y otros horarios)',
    );
  });
}
