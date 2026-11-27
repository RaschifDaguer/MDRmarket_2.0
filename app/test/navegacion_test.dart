import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/maps/ruta.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/repartidor/data/envio_ubicacion.dart';
import 'package:mdrmarket/features/repartidor/domain/repartidor.dart';
import 'package:mdrmarket/features/repartidor/presentation/navegacion_screen.dart';
import 'package:mdrmarket/features/repartidor/presentation/pedido_actual_screen.dart';

import 'falsos.dart';

/// Modo GPS del repartidor ("Cómo llegar"), con un GPS y una ruta simulados.
void main() {
  const inicio = Coordenada(-17.78, -63.19);
  const tienda = Coordenada(-17.7745, -63.1935);
  const casa = Coordenada(-17.79, -63.18);

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<({RepartidorFalso repartidor, StreamController<LecturaGps> gps, MapasFalso mapas, List<Uri> abiertos})> abrir(
    WidgetTester tester, {
    EstadoPedido estado = EstadoPedido.listo,
    ThemeData? tema,
    MapasFalso? mapas,
  }) async {
    final repartidor = RepartidorFalso(perfil: const PerfilRepartidor(estado: 'aprobado', disponible: true))
      ..actual = pedidoDeEjemplo(estado: estado, paraNegocio: true, tienda: tienda, casa: casa);
    final gps = StreamController<LecturaGps>.broadcast();
    addTearDown(gps.close);
    final rutas = mapas ?? MapasFalso(rutaFija: rutaEnL);
    final abiertos = <Uri>[];
    final router = GoRouter(
      initialLocation: '/repartidor/navegar',
      routes: [
        GoRoute(path: '/repartidor/navegar', builder: (_, _) => const NavegacionScreen()),
        GoRoute(path: '/repartidor/entregar', builder: (_, _) => const Scaffold(body: Text('pantalla del PIN'))),
        GoRoute(path: '/inicio', builder: (_, _) => const Scaffold(body: Text('inicio'))),
      ],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ...overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor, fuenteGps: () => gps.stream, mapas: rutas),
          abrirEnlaceProvider.overrideWithValue((uri) async {
            abiertos.add(uri);
            return true;
          }),
        ].cast(),
        child: MaterialApp.router(theme: tema ?? AppTheme.claro, routerConfig: router),
      ),
    );
    await esperar(tester);
    return (repartidor: repartidor, gps: gps, mapas: rutas, abiertos: abiertos);
  }

  Future<void> cerrarTodo(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  test('textos del GPS', () {
    expect(textoDistancia(347), '350 m');
    expect(textoDistancia(2430), '2,4 km');
    expect(textoTiempo(30), 'menos de 1 min');
    expect(textoTiempo(141), '3 min');
    expect(textoTiempo(3900), '1 h 5 min');
    expect(horaDeLlegada(600, ahora: DateTime(2026, 11, 27, 15, 32)), '15:42');
    expect(iconoManiobra(const PasoRuta(instruccion: '', tipo: 'turn', modificador: 'left', punto: inicio, indice: 1)),
        Icons.turn_left);
    expect(iconoManiobra(const PasoRuta(instruccion: '', tipo: 'roundabout', modificador: 'right', punto: inicio, indice: 1)),
        Icons.roundabout_right);
  });

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    testWidgets('tema $nombre: sin GPS todavía, lo espera; con GPS, la indicación, el tiempo y la hora', (tester) async {
      final a = await abrir(tester, tema: tema);
      expect(find.text('Buscando tu ubicación…'), findsOneWidget);
      expect(find.text('Recoger en Pollos Marta'), findsOneWidget);

      a.gps.add(const LecturaGps(inicio));
      await esperar(tester);
      // Ruta por las calles desde donde está, pasando por la tienda hasta la casa.
      expect(a.mapas.rutasPedidas.last, [inicio, tienda, casa]);
      expect(find.text('Gira a la derecha hacia Av. Busch'), findsOneWidget);
      expect(find.text('En 370 m'), findsOneWidget);
      // Hasta la tienda: ~983 m a 25 km/h = 2,4 min → 3 min.
      expect(find.text('3 min'), findsOneWidget);
      expect(find.textContaining('980 m · llegas '), findsOneWidget);
      expect(find.byKey(const Key('entrega-estimada')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await cerrarTodo(tester);
    });
  }

  testWidgets('al llegar a la tienda: "Ya lo recogí" y la ruta sigue a la casa del cliente', (tester) async {
    final a = await abrir(tester);
    a.gps.add(const LecturaGps(inicio));
    await esperar(tester);
    expect(find.byKey(const Key('gps-recogido')), findsNothing);

    a.gps.add(const LecturaGps(Coordenada(-17.7746, -63.1935))); // a ~11 m de la tienda
    await esperar(tester);
    expect(find.text('Llegaste a Pollos Marta'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gps-recogido')));
    await esperar(tester);

    expect(a.repartidor.actual!.estado, EstadoPedido.enCamino);
    expect(find.text('Entregar a Lucía Rojas'), findsOneWidget);
    expect(find.text('Cobras Bs 73,00 en efectivo'), findsOneWidget);
    // La ruta nueva va de donde está a la casa (ya sin la tienda).
    expect(a.mapas.rutasPedidas.last, [const Coordenada(-17.7746, -63.1935), casa]);
    await cerrarTodo(tester);
  });

  testWidgets('al llegar a la casa: "Entregar con el PIN"; y se puede llamar al cliente', (tester) async {
    final a = await abrir(tester, estado: EstadoPedido.enCamino);
    a.gps.add(const LecturaGps(Coordenada(-17.78995, -63.18))); // a ~6 m de la casa
    await esperar(tester);
    expect(find.text('Llegaste a la casa de Lucía Rojas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gps-llamar')));
    await tester.pump();
    expect(a.abiertos.single.toString(), 'tel:70011122');

    await tester.tap(find.byKey(const Key('gps-entregar')));
    await esperar(tester);
    expect(find.text('pantalla del PIN'), findsOneWidget);
    await cerrarTodo(tester);
  });

  testWidgets('sin servicio de rutas: línea recta y lo avisa', (tester) async {
    final a = await abrir(tester, mapas: MapasFalso());
    a.gps.add(const LecturaGps(inicio));
    await esperar(tester);
    expect(find.text('Ruta aproximada: ahora no pudimos calcularla por las calles.'), findsOneWidget);
    expect(find.byKey(const Key('tiempo-gps')), findsOneWidget);
    await cerrarTodo(tester);
  });

  testWidgets('GPS apagado: avisa arriba con el botón para encenderlo', (tester) async {
    final a = await abrir(tester);
    a.gps.add(const LecturaGps(null, gpsApagado: true));
    await esperar(tester);
    expect(find.text('Enciende tu GPS para repartir'), findsOneWidget);
    expect(find.byKey(const Key('activar-ubicacion')), findsOneWidget);
    await cerrarTodo(tester);
  });

  testWidgets('si ya no tiene el pedido (lo cancelaron), lo dice', (tester) async {
    final a = await abrir(tester);
    a.repartidor.actual = null;
    await tester.pump(const Duration(seconds: 9)); // se actualiza solo
    await esperar(tester);
    expect(find.text('Ya no tienes un pedido en curso'), findsOneWidget);
    await cerrarTodo(tester);
  });
}
