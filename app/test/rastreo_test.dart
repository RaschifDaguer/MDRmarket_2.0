import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/pedidos/domain/seguimiento.dart';
import 'package:mdrmarket/features/pedidos/presentation/pedido_screen.dart';
import 'package:mdrmarket/features/pedidos/presentation/widgets/seguimiento_pedido.dart';
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
      {ThemeData? tema, List<Seguimiento>? seguimientos, MapaDelSeguimiento? mapa, MapasFalso? mapas}) async {
    final pedidos = PedidosFalso(pedidoActual: pedidoDeEjemplo(estado: EstadoPedido.enCamino, conRepartidor: true))
      ..seguimientos = seguimientos ?? [enCamino()];
    await abrirConFalsos(tester, const PedidoScreen(pedidoId: 42),
        overrides: overridesFalsos(usuario: cliente, pedidos: pedidos, mapa: mapa, mapas: mapas), tema: tema);
    await tester.pump(const Duration(milliseconds: 300));
    return pedidos;
  }

  /// El mapa falso guarda la última línea que le pasaron.
  List<Coordenada> lineaDibujada = const [];
  bool lineaPorCalles = false;
  Widget mapaFalso(Seguimiento s, List<Coordenada> ruta, bool porCalles) {
    lineaDibujada = ruta;
    lineaPorCalles = porCalles;
    return Container(key: const Key('mapa-falso'), color: Colors.transparent);
  }

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

    await tester.pump(intervaloSeguimiento + const Duration(seconds: 1)); // pasa el intervalo de 4 s
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Llega en unos 3 min'), findsOneWidget);
    expect(find.textContaining('A 0,9 km'), findsOneWidget);
    expect(pedidos.consultasSeguimiento, greaterThanOrEqualTo(2));
    await cerrar(tester);
  });

  testWidgets('con ruta por las calles: la línea sigue las calles y el tiempo sale de la ruta', (tester) async {
    final mapas = MapasFalso(rutaFija: rutaEnL);
    await abrirPedido(tester, mapa: mapaFalso, mapas: mapas);
    await tester.pump(const Duration(milliseconds: 300));

    // Ya lo recogió: la ruta va del repartidor a la casa (sin pasar por la tienda).
    expect(mapas.rutasPedidas.single, [const Coordenada(-17.776, -63.19), const Coordenada(-17.79, -63.18)]);
    expect(lineaPorCalles, isTrue);
    expect(lineaDibujada, hasLength(3)); // con el codo de la calle, no en diagonal
    // 2,6 km por las calles (1,06 + 1,56) a 25 km/h = 6,3 min → 7 (la API decía 8 y 2,4 km en línea recta).
    expect(find.text('Llega en unos 7 min'), findsOneWidget);
    expect(find.textContaining('A 2,6 km'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('sin servicio de rutas: línea recta y el tiempo de la API', (tester) async {
    await abrirPedido(tester, mapa: mapaFalso);
    expect(lineaPorCalles, isFalse);
    expect(lineaDibujada, [const Coordenada(-17.776, -63.19), const Coordenada(-17.79, -63.18)]);
    expect(find.text('Llega en unos 8 min'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('el repartidor llegó a la casa: "¡Tu repartidor llegó!"', (tester) async {
    // A ~45 m del punto que marcó el cliente (lo normal por el error del GPS).
    await abrirPedido(tester, seguimientos: [enCamino(repartidor: const Coordenada(-17.7896, -63.1802))]);
    expect(find.text('¡Tu repartidor llegó!'), findsOneWidget);
    expect(find.textContaining('Sal a recibirlo y dale tu PIN'), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('todavía no lo recogió y está en la tienda: lo dice', (tester) async {
    const enTienda = Seguimiento(
      estado: EstadoPedido.listo,
      negocioNombre: 'Pollos Marta',
      negocio: Coordenada(-17.7745, -63.1935),
      destino: Coordenada(-17.79, -63.18),
      repartidor: Coordenada(-17.7747, -63.1933),
      haceSegundos: 3,
    );
    await abrirPedido(tester, seguimientos: [enTienda]);
    expect(find.text('Tu repartidor está en Pollos Marta'), findsOneWidget);
    expect(find.textContaining('Está recogiendo tu pedido'), findsOneWidget);
    await cerrar(tester);
  });

  group('Repartidor: GPS en vivo', () {
    testWidgets('sin señal (bajo techo): usa la ubicación aproximada y si no hay, avisa', (tester) async {
      final repartidor = RepartidorFalso(perfil: const PerfilRepartidor(estado: 'aprobado', disponible: true))
        ..actual = pedidoDeEjemplo(estado: EstadoPedido.enCamino, paraNegocio: true);
      final callado = StreamController<LecturaGps>.broadcast(); // el GPS preciso no da nada
      addTearDown(callado.close);
      Coordenada? aproximada;
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(
            usuario: repartidorAprobado,
            repartidor: repartidor,
            fuenteGps: () => callado.stream,
            leerGpsUnaVez: () async => aproximada,
          ));
      await tester.pump(EnvioUbicacion.vigia * 2 + const Duration(seconds: 1));
      expect(find.byKey(const Key('aviso-senal')), findsOneWidget);
      expect(find.text('Buscando la señal del GPS…'), findsOneWidget);
      expect(repartidor.ubicacionesEnviadas, isEmpty);

      // El teléfono da su ubicación aproximada (wifi y antenas): se usa y se manda.
      aproximada = const Coordenada(-17.7801, -63.1802);
      await tester.pump(EnvioUbicacion.vigia + const Duration(milliseconds: 300));
      expect(find.byKey(const Key('aviso-senal')), findsNothing);
      expect(repartidor.ubicacionesEnviadas, [const Coordenada(-17.7801, -63.1802)]);
      await cerrar(tester);
    });

    RepartidorFalso conPedido() => RepartidorFalso(perfil: const PerfilRepartidor(estado: 'aprobado', disponible: true))
      ..actual = pedidoDeEjemplo(estado: EstadoPedido.enCamino, paraNegocio: true);

    testWidgets('manda cada posición nueva, sin pasarse del límite de la API', (tester) async {
      final repartidor = conPedido();
      final gps = StreamController<LecturaGps>();
      addTearDown(gps.close);
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor, fuenteGps: () => gps.stream));

      gps.add(const LecturaGps(Coordenada(-17.780, -63.180)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(repartidor.ubicacionesEnviadas, [const Coordenada(-17.780, -63.180)]); // la primera, enseguida

      // Se mueve dos veces enseguida: no manda hasta que pasen 4 s, y entonces la más reciente.
      gps.add(const LecturaGps(Coordenada(-17.781, -63.181)));
      gps.add(const LecturaGps(Coordenada(-17.782, -63.182)));
      await tester.pump(const Duration(seconds: 1));
      expect(repartidor.ubicacionesEnviadas, hasLength(1));
      await tester.pump(EnvioUbicacion.minimoEntreEnvios);
      expect(repartidor.ubicacionesEnviadas.last, const Coordenada(-17.782, -63.182));
      expect(repartidor.ubicacionesEnviadas, hasLength(2));
      await cerrar(tester);
    });

    testWidgets('quieto: repite la última posición cada pocos segundos (el cliente ve que sigue)', (tester) async {
      final repartidor = conPedido();
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor));
      await tester.pump(const Duration(milliseconds: 100));
      expect(repartidor.ubicacionesEnviadas, hasLength(1));
      await tester.pump(EnvioUbicacion.latido * 2 + const Duration(seconds: 1));
      expect(repartidor.ubicacionesEnviadas.length, greaterThanOrEqualTo(2));
      expect(repartidor.ubicacionesEnviadas.toSet(), {const Coordenada(-17.78, -63.18)});
      await cerrar(tester);
    });

    testWidgets('sin pedido activo no lee ni manda nada', (tester) async {
      final repartidor = RepartidorFalso(perfil: const PerfilRepartidor(estado: 'aprobado', disponible: true));
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor));
      await tester.pump(EnvioUbicacion.latido * 2);
      expect(repartidor.ubicacionesEnviadas, isEmpty);
      await cerrar(tester);
    });

    testWidgets('sin permiso: avisa, el botón pide el permiso y al darlo vuelve a mandar', (tester) async {
      final repartidor = conPedido();
      var permiso = false;
      var ajustesAbiertos = 0;
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(
            usuario: repartidorAprobado,
            repartidor: repartidor,
            fuenteGps: () => Stream.value(
              permiso ? const LecturaGps(Coordenada(-17.78, -63.18)) : const LecturaGps(null, sinPermiso: true),
            ),
            abrirAjustesGps: (_) async {
              ajustesAbiertos++;
              permiso = true;
            },
          ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('aviso-ubicacion')), findsOneWidget);
      expect(find.text('Necesitamos tu ubicación para repartir'), findsOneWidget);
      expect(repartidor.ubicacionesEnviadas, isEmpty);

      await tester.tap(find.byKey(const Key('activar-ubicacion')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ajustesAbiertos, 1);
      expect(find.byKey(const Key('aviso-ubicacion')), findsNothing);
      expect(repartidor.ubicacionesEnviadas, [const Coordenada(-17.78, -63.18)]);
      expect(tester.takeException(), isNull);
      await cerrar(tester);
    });

    testWidgets('GPS apagado: lo dice y reintenta solo cuando lo enciende', (tester) async {
      final repartidor = conPedido();
      var encendido = false;
      await abrirConFalsos(tester, const VistaRepartidor(),
          overrides: overridesFalsos(
            usuario: repartidorAprobado,
            repartidor: repartidor,
            fuenteGps: () => Stream.value(
              encendido ? const LecturaGps(Coordenada(-17.78, -63.18)) : const LecturaGps(null, gpsApagado: true),
            ),
          ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Enciende tu GPS para repartir'), findsOneWidget);
      expect(find.text('Encender GPS'), findsOneWidget);

      encendido = true; // lo enciende desde la barra del teléfono, sin tocar el botón
      await tester.pump(EnvioUbicacion.reintentoGps + const Duration(milliseconds: 300));
      expect(find.byKey(const Key('aviso-ubicacion')), findsNothing);
      expect(repartidor.ubicacionesEnviadas, hasLength(1));
      await cerrar(tester);
    });
  });
}
