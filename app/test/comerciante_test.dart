import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/app.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/comerciante/presentation/pestanas/ganancias_tab.dart';
import 'package:mdrmarket/features/comerciante/presentation/producto_form_screen.dart';
import 'package:mdrmarket/features/comerciante/presentation/registrar_negocio_screen.dart';
import 'package:mdrmarket/features/inicio/presentation/vistas/inicio_cliente.dart';
import 'package:mdrmarket/features/inicio/presentation/vistas/inicio_comerciante.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';

import 'falsos.dart';

/// Pantallas del comerciante (y la invitación desde la vista cliente), con
/// datos falsos: no usan internet.
void main() {
  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// La app completa con la sesión del comerciante y su negocio aprobado.
  Future<void> abrirApp(WidgetTester tester, {MiNegocioFalso? miNegocio}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: overridesFalsos(usuario: comerciante, negocios: const [negocioAprobado], miNegocio: miNegocio).cast(),
      child: const MdrMarketApp(),
    ));
    await esperar(tester);
  }

  group('Registrar mi negocio', () {
    testWidgets('sin datos, avisa todo lo que falta y no envía', (tester) async {
      await abrirConFalsos(tester, const RegistrarNegocioScreen(),
          overrides: overridesFalsos(usuario: cliente, faltantes: faltaCarnet));

      final boton = find.widgetWithText(FilledButton, 'Registrar negocio');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Escribe el nombre del negocio'), findsOneWidget);
      expect(find.text('Elige el rubro de tu negocio'), findsOneWidget);
      expect(find.text('Escribe la dirección'), findsOneWidget);
      expect(find.text('Marca la ubicación del negocio en el mapa o con el GPS.'), findsOneWidget);
      expect(find.text('Agrega una foto del negocio.'), findsOneWidget);
      expect(find.text('Agrega la foto del frente de tu carnet.'), findsOneWidget);
      expect(find.text('Agrega la foto del reverso de tu carnet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pide el carnet si falta', (tester) async {
      await abrirConFalsos(tester, const RegistrarNegocioScreen(),
          overrides: overridesFalsos(usuario: cliente, faltantes: faltaCarnet));
      expect(find.text('Tu carnet de identidad'), findsOneWidget);
    });

    testWidgets('no pide el carnet si ya lo subió', (tester) async {
      await abrirConFalsos(tester, const RegistrarNegocioScreen(), overrides: overridesFalsos(usuario: cliente));
      expect(find.text('Tu carnet de identidad'), findsNothing);
      // NIT y nombre para facturas (razón social) son opcionales.
      expect(find.text('Datos para facturas'), findsOneWidget);
      expect(find.text('Nombre para facturas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra los rubros de la API', (tester) async {
      await abrirConFalsos(tester, const RegistrarNegocioScreen(), overrides: overridesFalsos(usuario: cliente));
      await tester.tap(find.text('Rubro'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Salud y Belleza'), findsWidgets);
    });

    testWidgets('sin mapa, ofrece el GPS', (tester) async {
      await abrirConFalsos(tester, const RegistrarNegocioScreen(), overrides: overridesFalsos(usuario: cliente));
      expect(find.text('Usar mi ubicación'), findsOneWidget);
    });
  });

  group('Vista cliente', () {
    testWidgets('invita a registrar un negocio si no tiene', (tester) async {
      await abrirConFalsos(tester, const InicioCliente(usuario: cliente), overrides: overridesFalsos(usuario: cliente));
      expect(find.text('¿Tienes un negocio?'), findsOneWidget);
    });

    testWidgets('no lo muestra si ya es comerciante', (tester) async {
      await abrirConFalsos(tester, const InicioCliente(usuario: comerciante), overrides: overridesFalsos(usuario: comerciante));
      expect(find.text('¿Tienes un negocio?'), findsNothing);
    });
  });

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Vista comerciante (tema $nombre)', () {
      testWidgets('negocio en revisión con lo que falta', (tester) async {
        await abrirConFalsos(
          tester,
          const InicioComerciante(usuario: comerciante),
          overrides: overridesFalsos(usuario: comerciante, negocios: const [negocioEnRevision], faltantes: faltaCarnet),
          tema: tema,
        );
        expect(find.text('Negocio en revisión'), findsOneWidget);
        expect(find.text('Tienda Marta'), findsOneWidget);
        expect(find.text('Para activar tu negocio te falta'), findsOneWidget);
        expect(find.text('Subir'), findsNWidgets(2));
        expect(find.text('Productos'), findsOneWidget); // pestañas de abajo
        expect(tester.takeException(), isNull);
      });

      testWidgets('negocio activo: números del día y sin faltantes', (tester) async {
        await abrirConFalsos(
          tester,
          const InicioComerciante(usuario: comerciante),
          overrides: overridesFalsos(usuario: comerciante, negocios: const [negocioAprobado]),
          tema: tema,
        );
        expect(find.text('¡Tu negocio está activo!'), findsOneWidget);
        expect(find.text('Para activar tu negocio te falta'), findsNothing);
        await tester.scrollUntilVisible(find.text('Pedidos nuevos'), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text('Bs 350,00'), findsOneWidget); // ventas de hoy
        expect(tester.takeException(), isNull);
      });

      testWidgets('sin negocio: botón para registrarlo', (tester) async {
        await abrirConFalsos(tester, const InicioComerciante(usuario: comerciante),
            overrides: overridesFalsos(usuario: comerciante), tema: tema);
        expect(find.text('Todavía no tienes un negocio'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Registrar mi negocio'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('productos: la lista y el formulario revisa los datos', (tester) async {
    await abrirApp(tester);

    await tester.tap(find.text('Productos'));
    await esperar(tester);
    expect(find.text('Pollo a la broaster'), findsOneWidget);
    expect(find.text('Sin stock'), findsOneWidget);
    expect(find.text('Oculto'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nuevo-producto')));
    await esperar(tester);
    expect(find.text('Nuevo producto'), findsOneWidget);

    // Sin datos: no guarda y dice qué falta.
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar producto'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Escribe el nombre del producto'), findsOneWidget);
    expect(find.text('Escribe el precio'), findsOneWidget);

    // Oferta más cara que el precio: no se puede.
    await tester.enterText(find.byKey(const Key('campo-nombre')), 'Alitas');
    await tester.enterText(find.byKey(const Key('campo-precio')), '30');
    final formulario = find.descendant(of: find.byType(ProductoFormScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Está en oferta'), 200, scrollable: formulario);
    // Al centro de la pantalla: ni debajo del botón fijo ni pegado al borde de arriba.
    Scrollable.ensureVisible(tester.element(find.text('Está en oferta')), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Está en oferta'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('campo-oferta')), '35');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar producto'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tiene que ser menor al precio normal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrarApp(tester);
  });

  testWidgets('pedido en camino: se entrega solo con el PIN correcto', (tester) async {
    final miNegocio = MiNegocioFalso();
    await abrirApp(tester, miNegocio: miNegocio);

    await tester.tap(find.text('Pedidos'));
    await esperar(tester);
    await tester.tap(find.byKey(const Key('pedido-negocio-42')));
    await esperar(tester);
    expect(find.text('Lucía Rojas'), findsOneWidget);
    expect(find.text('Nota: Sin sal'), findsOneWidget);

    Future<void> entregarCon(String pin) async {
      await tester.tap(find.byKey(const Key('accion-entregado')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const Key('campo-pin')), pin);
      await tester.tap(find.text('Confirmar'));
      await esperar(tester);
    }

    await entregarCon('1111');
    expect(find.text('El PIN no coincide. Pídeselo de nuevo al cliente.'), findsOneWidget);
    expect(miNegocio.cambios, isEmpty);

    await tester.pump(const Duration(seconds: 5)); // se va el aviso
    await entregarCon('4821');
    expect(miNegocio.cambios, [EstadoPedido.entregado]);
    expect(miNegocio.pinRecibido, '4821');
    expect(find.byKey(const Key('accion-entregado')), findsNothing);
    expect(tester.takeException(), isNull);
    await cerrarApp(tester);
  });

  testWidgets('ganancias: totales, gráfico y por producto', (tester) async {
    await abrirApp(tester);
    await tester.tap(find.text('Ganancias'));
    await esperar(tester);

    expect(find.text('Ganancia neta'), findsOneWidget);
    expect(find.text('Bs 100,00'), findsOneWidget);
    expect(find.text('Ventas y ganancia'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pollo a la broaster'), 300,
        scrollable: find.descendant(of: find.byType(GananciasTab), matching: find.byType(Scrollable)).first);
    expect(find.text('43% margen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cerrarApp(tester);
  });
}

/// Desarma la app al final (cancela los relojes que actualizan los pedidos).
Future<void> cerrarApp(WidgetTester tester) => cerrar(tester);
