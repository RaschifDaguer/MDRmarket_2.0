import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/pedidos/domain/seguimiento.dart';
import 'package:mdrmarket/features/pedidos/presentation/pedido_screen.dart';
import 'package:mdrmarket/features/repartidor/data/envio_ubicacion.dart';
import 'package:mdrmarket/features/repartidor/domain/repartidor.dart';
import 'package:mdrmarket/features/repartidor/presentation/vista_repartidor.dart';

import 'falsos.dart';

/// Rastreo del pedido en el mapa (módulo 9), con datos simulados: sin internet
/// ni GPS real.
void main() {
  Seguimiento enCamino({int minutos = 8, double km = 2.4, Coordenada repartidor = const Coordenada(-17.776, -63.19)}) =>
      Seguimiento(
        estado: EstadoPedido.enCamino,
        negocioNombre: 'Pollos Marta',
        negocio: const Coordenada(-17.7745, -63.1935),
        destino: const Coordenada(-17.79, -63.18),
        repartidorNombre: 'Diego Rodríguez',
        vehiculo: 'Moto',
        placa: '1234-ABC',
        repartidor: repartidor,
        haceSegundos: 4,
        distanciaKm: km,
        tiempoMin: minutos,
      );

  /// El detalle del pedido del cliente, en camino y con repartidor.
  Future<PedidosFalso> abrirPedido(WidgetTester tester,
      {ThemeData? tema, List<Seguimiento>? seguimientos, Widget Function(Seguimiento)? mapa}) async {
    final pedidos = PedidosFalso(pedidoActual: pedidoDeEjemplo(estado: EstadoPedido.enCamino, conRepartidor: true))
      ..seguimientos = seguimientos ?? [enCamino()];
    await abrirConFalsos(tester, const PedidoScreen(pedidoId: 42),
        overrides: overridesFalsos(usuario: cliente, pedidos: pedidos, mapa: mapa), tema: tema);
    await tester.pump(const Duration(milliseconds: 300));
    return pedidos;
  }

  Widget mapaFalso(Seguimiento s) => Container(key: const Key('mapa-falso'), color: Colors.transparent);

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Tema $nombre', () {
      testWidgets('sin clave de Maps: distancia y tiempo en texto', (tester) async {
        await abrirPedido(tester, tema: tema);
        expect(find.text('Llega en unos 8 min'), findsOneWidget);
        expect(find.textContaining('A 2,4 km'), findsOneWidget);
        expect(find.textContaining('actualizado hace 4 s'), findsOneWidget);
        expect(find.text('El mapa no está disponible en este dispositivo.'), findsOneWidget);
        expect(find.byKey(const Key('mapa-falso')), findsNothing);
        expect(tester.takeException(), isNull);
        await cerrar(tester);
      });

      testWidgets('con mapa: el mapa arriba y el tiempo estimado', (tester) async {
        await abrirPedido(tester, tema: tema, mapa: mapaFalso);
        expect(find.byKey(const Key('mapa-falso')), findsOneWidget);
        expect(find.text('Llega en unos 8 min'), findsOneWidget);
        expect(find.text('El mapa no está disponible en este dispositivo.'), findsNothing);
        expect(tester.takeException(), isNull);
        await cerrar(tester);
      });
    });
  }

  testWidgets('se actualiza solo cada pocos segundos', (tester) async {
    final pedidos = await abrirPedido(tester, seguimientos: [
      enCamino(),
      enCamino(minutos: 3, km: 0.9, repartidor: const Coordenada(-17.786, -63.183)),
    ]);
    expect(find.text('Llega en unos 8 min'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7)); // pasa el intervalo de 6 s
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Llega en unos 3 min'), findsOneWidget);
    expect(find.textContaining('A 0,9 km'), findsOneWidget);
    expect(pedidos.consultasSeguimiento, greaterThanOrEqualTo(2));
    await cerrar(tester);
  });

  group('Repartidor', () {
    RepartidorFalso conPedido() => RepartidorFalso(perfil: const PerfilRepartidor(estado: 'aprobado', disponible: true))
      ..actual = pedidoDeEjemplo(estado: EstadoPedido.enCamino, paraNegocio: true);

    testWidgets('con un pedido activo manda su GPS cada pocos segundos', (tester) async {
      final repartidor = conPedido();
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repartidor.ubicacionesEnviadas, hasLength(1)); // la primera, enseguida

      await tester.pump(EnvioUbicacion.intervalo);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repartidor.ubicacionesEnviadas, hasLength(2));
      expect(repartidor.ubicacionesEnviadas.last, const Coordenada(-17.78, -63.18));
      await cerrar(tester);
    });

    testWidgets('sin pedido activo no manda nada', (tester) async {
      final repartidor = RepartidorFalso(perfil: const PerfilRepartidor(estado: 'aprobado', disponible: true));
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor));
      await tester.pump(EnvioUbicacion.intervalo * 2);
      expect(repartidor.ubicacionesEnviadas, isEmpty);
      await cerrar(tester);
    });

    testWidgets('sin permiso de ubicación avisa que la necesita', (tester) async {
      final repartidor = conPedido();
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor, gps: const LecturaGps(null, sinPermiso: true)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('aviso-ubicacion')), findsOneWidget);
      expect(find.text('Necesitamos tu ubicación para repartir'), findsOneWidget);
      expect(repartidor.ubicacionesEnviadas, isEmpty);
      expect(tester.takeException(), isNull);
      await cerrar(tester);
    });
  });
}
