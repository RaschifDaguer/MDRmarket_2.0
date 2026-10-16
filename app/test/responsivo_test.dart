import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/app.dart';
import 'package:mdrmarket/core/router/app_router.dart';
import 'package:mdrmarket/features/carrito/presentation/carrito_controller.dart';
import 'package:mdrmarket/features/comerciante/presentation/registrar_negocio_screen.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';

import 'falsos.dart';

/// Revisa que las pantallas no se desborden en celular chico, celular, tablet
/// y laptop (y con letra grande). Con la fuente real de la marca.
///
/// Para guardar una imagen de cada pantalla en build/capturas/:
///   flutter test test/responsivo_test.dart --dart-define=CAPTURAS=true
const _capturas = bool.fromEnvironment('CAPTURAS');

const _tamanos = {
  'celular-chico': Size(360, 740),
  'celular': Size(390, 844),
  'tablet': Size(820, 1180),
  'laptop': Size(1366, 768),
};

const _raiz = Key('raiz');

/// Carga la fuente de la marca y los íconos (en las pruebas, por defecto
/// cada letra es un cuadrado).
Future<void> _cargarFuentes() async {
  final marca = FontLoader('PlusJakartaSans');
  for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    marca.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$peso.ttf'));
  }
  await marca.load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

void main() {
  setUpAll(_cargarFuentes);

  /// Abre la app completa en [ruta] (con datos falsos) y deja que cargue.
  Future<ProviderContainer> abrir(
    WidgetTester tester,
    Size tamano, {
    String ruta = '/inicio',
    bool comoComerciante = false,
    PedidosFalso? pedidos,
    MiNegocioFalso? miNegocio,
    bool conCarrito = false,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final contenedor = ProviderContainer(
      retry: (_, _) => null,
      overrides: overridesFalsos(
        usuario: comoComerciante ? comerciante : cliente,
        negocios: comoComerciante ? const [negocioAprobado] : const [],
        faltantes: comoComerciante ? const [] : faltaIdentidad,
        pedidos: pedidos,
        miNegocio: miNegocio,
      ).cast(),
    );
    addTearDown(contenedor.dispose);
    if (conCarrito) {
      contenedor.read(carritoProvider.notifier)
        ..agregar(pollo, 2)
        ..agregar(papas, 1);
    }
    await tester.pumpWidget(RepaintBoundary(
      key: _raiz,
      child: UncontrolledProviderScope(container: contenedor, child: const MdrMarketApp()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (ruta != '/inicio') {
      contenedor.read(routerProvider).push(ruta);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    return contenedor;
  }

  Future<void> guardar(WidgetTester tester, String nombre) async {
    if (!_capturas) return;
    final limite = tester.renderObject<RenderRepaintBoundary>(find.byKey(_raiz));
    await tester.runAsync(() async {
      final imagen = await limite.toImage();
      final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
      File('build/capturas/$nombre.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> cerrarYRevisar(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  }

  // Pantallas a revisar: nombre de la captura → cómo se abre.
  final pantallas = <String, Future<void> Function(WidgetTester, Size)>{
    '1-catalogo': (t, s) => abrir(t, s),
    '2-producto': (t, s) => abrir(t, s, ruta: '/producto/10'),
    '3-carrito': (t, s) => abrir(t, s, ruta: '/carrito', conCarrito: true),
    '4-confirmar': (t, s) => abrir(t, s, ruta: '/checkout', conCarrito: true),
    '5-pedido-cliente': (t, s) => abrir(t, s,
        ruta: '/pedido/42', pedidos: PedidosFalso(pedidoActual: pedidoDeEjemplo(acciones: const [EstadoPedido.cancelado]))),
    '6-resumen-comerciante': (t, s) => abrir(t, s, comoComerciante: true),
    '7-pedido-negocio': (t, s) => abrir(t, s, comoComerciante: true, ruta: '/negocio/pedido/42'),
    '8-producto-form': (t, s) => abrir(t, s, comoComerciante: true, ruta: '/negocio/producto'),
  };

  for (final MapEntry(key: dispositivo, value: tamano) in _tamanos.entries) {
    group(dispositivo, () {
      for (final MapEntry(key: nombre, value: abrirPantalla) in pantallas.entries) {
        testWidgets(nombre, (tester) async {
          await abrirPantalla(tester, tamano);
          expect(tester.takeException(), isNull);
          await guardar(tester, '$dispositivo-$nombre');
          await cerrarYRevisar(tester);
        });
      }
    });
  }

  testWidgets('pestañas del comerciante (celular)', (tester) async {
    await abrir(tester, const Size(390, 844), comoComerciante: true);
    for (final (pestana, archivo) in [('Productos', 'productos'), ('Pedidos', 'pedidos'), ('Ganancias', 'ganancias'), ('Más', 'mas')]) {
      await tester.tap(find.text(pestana));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
      await guardar(tester, 'celular-9-comerciante-$archivo');
    }
    await cerrarYRevisar(tester);
  });

  testWidgets('formulario de registro con errores (celular)', (tester) async {
    // Alto grande para ver el formulario entero en una sola imagen.
    await abrir(tester, const Size(390, 2300), ruta: '/registrar-negocio');
    expect(find.byType(RegistrarNegocioScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar negocio'));
    await tester.pump(const Duration(seconds: 1));
    // Un cuadro más: los errores de los campos aparecen con una animación.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Agrega una foto del negocio.'), findsOneWidget);
    await guardar(tester, 'celular-10-registrar-negocio-errores');
    await cerrarYRevisar(tester);
  });

  testWidgets('letra grande en celular chico', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await abrir(tester, const Size(360, 740));
    expect(tester.takeException(), isNull);
    await guardar(tester, 'celular-chico-11-letra-grande-catalogo');
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
    contenedor.read(routerProvider).push('/producto/10');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await guardar(tester, 'celular-chico-11-letra-grande-producto');
    await cerrarYRevisar(tester);
  });
}
