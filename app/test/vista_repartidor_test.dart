import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/repartidor/domain/pedido_disponible.dart';
import 'package:mdrmarket/features/repartidor/domain/repartidor.dart';
import 'package:mdrmarket/features/repartidor/presentation/pedido_actual_screen.dart';
import 'package:mdrmarket/features/repartidor/presentation/vista_repartidor.dart';

import 'falsos.dart';

/// Vista del repartidor aprobado (módulo 8) con datos simulados: no usa internet.
void main() {
  RepartidorFalso falso({bool enLinea = true, Pedido? actual}) => RepartidorFalso(
        perfil: PerfilRepartidor(estado: 'aprobado', disponible: enLinea),
      )
        ..listaDisponibles = disponiblesDePrueba
        ..actual = actual;

  Future<void> abrirVista(WidgetTester tester, RepartidorFalso repartidor, {ThemeData? tema}) =>
      abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor), tema: tema);

  Future<void> abrirPedido(WidgetTester tester, EstadoPedido estado, {ThemeData? tema, RepartidorFalso? repartidor}) =>
      abrirConFalsos(
        tester,
        const PedidoActualScreen(),
        overrides: overridesFalsos(
          usuario: repartidorAprobado,
          repartidor: repartidor ?? falso(actual: pedidoDeEjemplo(estado: estado, paraNegocio: true)),
        ),
        tema: tema,
      );

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Tema $nombre', () {
      testWidgets('en línea, con los pedidos disponibles', (tester) async {
        await abrirVista(tester, falso(), tema: tema);
        expect(find.text('En línea'), findsOneWidget);
        expect(find.text('Pedidos disponibles (2)'), findsOneWidget);
        expect(find.text('Pollos Marta'), findsOneWidget);
        expect(find.text('A 0.8 km de ti'), findsOneWidget);
        expect(find.text('Bs 5,00'), findsOneWidget); // lo que gana por el envío
        expect(find.text('Aceptar'), findsNWidgets(2));
        expect(find.text('Mis entregas'), findsOneWidget); // pestaña de abajo
        expect(tester.takeException(), isNull);
      });

      testWidgets('desconectado', (tester) async {
        await abrirVista(tester, falso(enLinea: false), tema: tema);
        expect(find.text('Desconectado'), findsOneWidget);
        expect(find.text('Estás desconectado'), findsOneWidget);
        expect(find.text('Aceptar'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('pedido actual sin recoger: "Recogido" y "Soltar pedido"', (tester) async {
        await abrirPedido(tester, EstadoPedido.listo, tema: tema);
        expect(find.text('Ve al negocio a recogerlo'), findsOneWidget);
        expect(find.text('Lucía Rojas'), findsOneWidget); // el cliente
        expect(find.text('Calle Libertad 123'), findsOneWidget);
        expect(find.text('Cobra Bs 73,00 en efectivo'), findsOneWidget);
        expect(find.byKey(const Key('boton-recogido')), findsOneWidget);
        expect(find.byKey(const Key('boton-soltar')), findsOneWidget);
        expect(find.byKey(const Key('boton-entregado')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('pedido actual en camino: "Entregado" y sin soltar', (tester) async {
        await abrirPedido(tester, EstadoPedido.enCamino, tema: tema);
        expect(find.text('Llévalo a la casa del cliente'), findsOneWidget);
        expect(find.byKey(const Key('boton-entregado')), findsOneWidget);
        expect(find.byKey(const Key('boton-soltar')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('mis entregas', (tester) async {
        final repartidor = falso()
          ..misEntregas = Entregas(
            pedidos: [pedidoDeEjemplo(estado: EstadoPedido.entregado, paraNegocio: true)],
            total: 1,
            totalEnvios: 5,
          );
        await abrirVista(tester, repartidor, tema: tema);
        await tester.tap(find.text('Mis entregas'));
        // Un cuadro para abrir la pestaña y otro para mostrar lo que cargó.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('1 entrega'), findsOneWidget);
        expect(find.text('Bs 5,00 en envíos'), findsOneWidget);
        expect(find.textContaining('#42'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('con un pedido en curso no deja aceptar otro', (tester) async {
    await abrirVista(tester, falso(actual: pedidoDeEjemplo(estado: EstadoPedido.listo, paraNegocio: true)));
    expect(find.text('Tu pedido en curso'), findsOneWidget);
    final aceptar = tester.widget<FilledButton>(find.ancestor(of: find.text('Aceptar').first, matching: find.byType(FilledButton)));
    expect(aceptar.onPressed, isNull);
  });

  testWidgets('si otro repartidor lo aceptó primero, avisa', (tester) async {
    final repartidor = falso()
      ..errorAceptar = ApiException('Datos inválidos', statusCode: 422, errores: {
        'pedido': ['Otro repartidor ya aceptó este pedido.'],
      });
    await abrirVista(tester, repartidor);
    await tester.tap(find.byKey(const Key('aceptar-42')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Otro repartidor ya aceptó este pedido.'), findsOneWidget);
  });

  group('PIN de entrega', () {
    Future<void> abrirDialogo(WidgetTester tester, RepartidorFalso repartidor) async {
      await abrirPedido(tester, EstadoPedido.enCamino, repartidor: repartidor);
      await tester.tap(find.byKey(const Key('boton-entregado')));
      await tester.pump(const Duration(seconds: 1));
    }

    TextField campo(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('campo-pin')));
    FilledButton confirmar(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('confirmar-pin')));

    testWidgets('solo acepta 4 números', (tester) async {
      await abrirDialogo(tester, falso(actual: pedidoDeEjemplo(estado: EstadoPedido.enCamino, paraNegocio: true)));

      await tester.enterText(find.byKey(const Key('campo-pin')), 'ab12x');
      await tester.pump();
      expect(campo(tester).controller!.text, '12'); // sin letras
      expect(confirmar(tester).onPressed, isNull); // faltan números

      await tester.enterText(find.byKey(const Key('campo-pin')), '4821999');
      await tester.pump();
      expect(campo(tester).controller!.text, '4821'); // como máximo 4
      expect(confirmar(tester).onPressed, isNotNull);
    });

    testWidgets('con el PIN equivocado lo vuelve a pedir con el error', (tester) async {
      final repartidor = falso(actual: pedidoDeEjemplo(estado: EstadoPedido.enCamino, paraNegocio: true));
      await abrirDialogo(tester, repartidor);

      await tester.enterText(find.byKey(const Key('campo-pin')), '1111');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirmar-pin')));
      await tester.pump(const Duration(seconds: 1));

      expect(repartidor.pinesProbados, ['1111']);
      expect(find.text('El PIN no coincide. Pídeselo de nuevo al cliente.'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('campo-pin')), findsNothing);
    });
  });
}
