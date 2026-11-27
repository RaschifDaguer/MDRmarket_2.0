// Mapa sin clave de Google (OpenStreetMap con flutter_map) y el tema, que es
// una sola preferencia para toda la app.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/maps/iconos_mapa.dart';
import 'package:mdrmarket/core/maps/mapa.dart';
import 'package:mdrmarket/core/maps/mapas.dart';
import 'package:mdrmarket/core/maps/mapas_repository.dart';
import 'package:mdrmarket/core/maps/selector_ubicacion.dart';
import 'package:mdrmarket/core/storage/preferencias.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/comerciante/presentation/pestanas/mas_tab.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/pedidos/domain/seguimiento.dart';
import 'package:mdrmarket/features/pedidos/presentation/widgets/seguimiento_pedido.dart';
import 'package:mdrmarket/features/repartidor/presentation/cuenta_repartidor.dart';

import 'falsos.dart';

void _nada(Coordenada _) {}

/// Teselas falsas: una imagen chica, sin pedir nada a internet.
class TeselasFalsas extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(fotoDePrueba.bytes);
}

void main() {
  group('Mapa sin clave de Google: OpenStreetMap', () {
    setUp(() => Mapas.teselasDePrueba = TeselasFalsas());
    tearDown(() => Mapas.teselasDePrueba = null);

    test('sin clave no se usa Google, pero hay mapa', () {
      expect(Mapas.google, isFalse);
      expect(Mapas.disponibles, isTrue);
      // Política de uso de OpenStreetMap: sus teselas y el user-agent de la app.
      expect(MapaMdr.urlTeselas, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      expect(MapaMdr.userAgent, 'bo.mdrmarket.app');
    });

    testWidgets('seguimiento: tienda, casa y la moto, con la atribución visible', (tester) async {
      const seguimiento = Seguimiento(
        estado: EstadoPedido.enCamino,
        negocioNombre: 'Pollos Marta',
        negocio: Coordenada(-17.77, -63.19),
        destino: Coordenada(-17.79, -63.17),
        repartidor: Coordenada(-17.78, -63.18),
        repartidorNombre: 'Diego',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 300, child: MapaSeguimiento(seguimiento: seguimiento)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const Key('marcador-tienda')), findsOneWidget);
      expect(find.byKey(const Key('marcador-casa')), findsOneWidget);
      expect(find.byKey(const Key('marcador-repartidor')), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget); // la línea de la moto a la casa
      expect(find.text('© OpenStreetMap'), findsOneWidget);

      // Llega una posición nueva: la moto se mueve (sin errores al reencuadrar).
      const despues = Seguimiento(
        estado: EstadoPedido.enCamino,
        negocioNombre: 'Pollos Marta',
        negocio: Coordenada(-17.77, -63.19),
        destino: Coordenada(-17.79, -63.17),
        repartidor: Coordenada(-17.785, -63.175),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 300, child: MapaSeguimiento(seguimiento: despues)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('marcador-repartidor')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selector de dirección: se elige el punto tocando el mapa y sale la calle, no las coordenadas',
        (tester) async {
      Coordenada? elegido;
      DireccionEncontrada? encontrada;
      final mapas = MapasFalso();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mapasRepositoryProvider.overrideWithValue(mapas)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => SelectorUbicacion(
                    valor: elegido,
                    alCambiar: (c) => setState(() => elegido = c),
                    alEncontrarDireccion: (d) => encontrada = d,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('mapa-selector')), findsOneWidget);
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      expect(find.text('Usar mi ubicación'), findsOneWidget); // el GPS sigue
      expect(find.text('Ubicación sin marcar'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mapa-selector')));
      await tester.pump(const Duration(milliseconds: 500)); // el mapa espera por si es doble toque
      expect(elegido, isNotNull);
      expect(elegido!.latitud, closeTo(Coordenada.centroSantaCruz.latitud, 0.05));
      expect(find.text('Buscando la dirección…'), findsOneWidget);

      await tester.pump(SelectorUbicacion.espera + const Duration(milliseconds: 100));
      expect(mapas.direccionesPedidas.single, elegido);
      expect(find.text('Calle Libertad 123, Equipetrol'), findsOneWidget);
      expect(find.text('Santa Cruz de la Sierra'), findsOneWidget);
      expect(find.textContaining('-17.'), findsNothing); // sin coordenadas a la vista
      expect(encontrada?.corta, 'Calle Libertad 123, Equipetrol');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin servicio de direcciones: "Ubicación marcada" y pide escribirla', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mapasRepositoryProvider.overrideWithValue(MapasFalso(direccionFija: null))],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: SelectorUbicacion(valor: Coordenada(-17.78, -63.18), alCambiar: _nada)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ubicación marcada en el mapa'), findsOneWidget);
      expect(find.text('No encontramos el nombre de la calle: escríbela abajo.'), findsOneWidget);
    });

    testWidgets('los íconos de Google Maps se dibujan (moto, persona, tienda)', (tester) async {
      await tester.runAsync(() async {
        for (final tipo in [TipoPunto.repartidor, TipoPunto.casa, TipoPunto.tienda]) {
          final (icono, color) = MapaMdr.estilo(tipo, AppTheme.claro.colorScheme);
          final png = await IconosMapa.dibujarPng(icono, color, 2);
          expect(png.sublist(1, 4), 'PNG'.codeUnits); // es un PNG
          expect(png.length, greaterThan(200));
        }
      });
      expect(MapaMdr.estilo(TipoPunto.repartidor, AppTheme.claro.colorScheme).$1, Icons.two_wheeler);
      expect(MapaMdr.estilo(TipoPunto.casa, AppTheme.claro.colorScheme).$1, Icons.person);
      expect(MapaMdr.estilo(TipoPunto.tienda, AppTheme.claro.colorScheme).$1, Icons.storefront);
    });
  });

  group('Tema: una sola preferencia para toda la app', () {
    testWidgets('se cambia en "Más" del comercio', (tester) async {
      final preferencias = PreferenciasEnMemoria();
      await abrirConFalsos(
        tester,
        const MasTab(negocio: negocioAprobado),
        overrides: overridesFalsos(usuario: comerciante, preferencias: preferencias),
        tamano: const Size(390, 1400),
      );
      await tester.tap(find.text('Oscuro'));
      await tester.pump();
      expect(preferencias.datos['tema'], 'dark');
      final contenedor = ProviderScope.containerOf(tester.element(find.byType(MasTab)));
      expect(contenedor.read(modoTemaProvider), ThemeMode.dark);
    });

    testWidgets('se cambia en la cuenta del repartidor', (tester) async {
      final preferencias = PreferenciasEnMemoria();
      await abrirConFalsos(
        tester,
        const CuentaRepartidor(),
        overrides: overridesFalsos(usuario: repartidorEnRevision, preferencias: preferencias),
      );
      expect(find.text('Cambiar a vista cliente'), findsOneWidget);
      await tester.tap(find.text('Claro'));
      await tester.pump();
      expect(preferencias.datos['tema'], 'light');
    });

    testWidgets('lo que se guardó vale para todos los roles', (tester) async {
      final preferencias = PreferenciasEnMemoria()..datos['tema'] = 'dark';
      await abrirConFalsos(
        tester,
        const CuentaRepartidor(),
        overrides: overridesFalsos(usuario: repartidorEnRevision, preferencias: preferencias),
      );
      await tester.pump();
      final seleccion = tester.widget<SegmentedButton<ThemeMode>>(find.byKey(const Key('selector-tema')));
      expect(seleccion.selected, {ThemeMode.dark});
    });
  });
}
