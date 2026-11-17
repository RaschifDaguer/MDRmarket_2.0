import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/core/widgets/widgets.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/repartidor/domain/pedido_disponible.dart';
import 'package:mdrmarket/features/repartidor/domain/repartidor.dart';
import 'package:mdrmarket/features/repartidor/presentation/entregar_pin_screen.dart';
import 'package:mdrmarket/features/repartidor/presentation/pedido_actual_screen.dart';
import 'package:mdrmarket/features/repartidor/presentation/vista_repartidor.dart';

import 'falsos.dart';

/// Vista del repartidor aprobado (fase 5) con datos simulados: no usa internet.
void main() {
  const moto = Vehiculo(id: 4, tipoCodigo: 'moto', tipoNombre: 'Moto', placa: '2345-XKD', estado: 'aprobado');

  RepartidorFalso falso({bool enLinea = true, Pedido? actual}) =>
      RepartidorFalso(
          perfil: PerfilRepartidor(estado: 'aprobado', disponible: enLinea, vehiculos: const [moto]),
        )
        ..listaDisponibles = disponiblesDePrueba
        ..actual = actual;

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> abrirVista(WidgetTester tester, RepartidorFalso repartidor, {ThemeData? tema}) => abrirConFalsos(
    tester,
    const VistaRepartidor(),
    overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor),
    tema: tema,
    tamano: const Size(390, 1400),
  );

  Future<void> abrirPedido(
    WidgetTester tester,
    EstadoPedido estado, {
    ThemeData? tema,
    RepartidorFalso? repartidor,
    List extra = const [],
  }) => abrirConFalsos(
    tester,
    const PedidoActualScreen(),
    overrides: [
      ...overridesFalsos(
        usuario: repartidorAprobado,
        repartidor: repartidor ?? falso(actual: pedidoDeEjemplo(estado: estado, paraNegocio: true)),
      ),
      ...extra,
    ],
    tema: tema,
    tamano: const Size(390, 1200),
  );

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Tema $nombre', () {
      testWidgets('pedidos cerca: saludo, en línea, lo de hoy y los disponibles', (tester) async {
        await abrirVista(tester, falso(), tema: tema);
        expect(find.text('Hola, Diego'), findsOneWidget);
        expect(find.text('Moto · 2345-XKD'), findsOneWidget);
        expect(find.text('En línea'), findsOneWidget);
        // Ganado hoy, meta y entregas de hoy (GET /api/repartidor/ganancias).
        expect(
          find.descendant(of: find.byKey(const Key('ganado-hoy')), matching: find.text('Bs 12,00')),
          findsOneWidget,
        );
        expect(find.text('Meta del día Bs 150,00'), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('entregas-hoy')), matching: find.text('2')), findsOneWidget);
        expect(find.text('Cerca de ti · 2 pedidos'), findsOneWidget);
        expect(find.text('Pollos Marta'), findsNothing); // va en el mismo texto que la dirección
        expect(find.textContaining('Pollos Marta'), findsOneWidget);
        expect(find.text('La tienda está a 0,8 km de ti'), findsOneWidget);
        expect(find.text('Paquete chico'), findsNWidgets(2));
        expect(find.text('Cobras Bs 73,00'), findsOneWidget); // en efectivo
        expect(find.text('Pagado con QR'), findsOneWidget);
        expect(find.text('Aceptar pedido'), findsNWidgets(2));
        expect(find.text('Mis entregas'), findsOneWidget); // pestaña de abajo
        expect(tester.takeException(), isNull);
      });

      testWidgets('desconectado', (tester) async {
        await abrirVista(tester, falso(enLinea: false), tema: tema);
        expect(find.text('Desconectado'), findsOneWidget);
        expect(find.text('Estás desconectado'), findsOneWidget);
        expect(find.text('Conéctate para ver pedidos cerca de ti.'), findsOneWidget);
        expect(find.text('Aceptar pedido'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('en curso, paso 1: recoger en la tienda', (tester) async {
        await abrirPedido(tester, EstadoPedido.listo, tema: tema);
        expect(find.byKey(const Key('pasos-reparto')), findsOneWidget);
        expect(find.byKey(const Key('destino-tienda')), findsOneWidget);
        expect(find.text('Pollos Marta'), findsOneWidget);
        expect(find.text('#42 · 3 productos'), findsOneWidget);
        expect(find.text('Bs 73,00 efectivo'), findsOneWidget);
        expect(find.byKey(const Key('como-llegar')), findsOneWidget);
        expect(find.text('Ya lo recogí'), findsOneWidget);
        expect(find.byKey(const Key('boton-soltar')), findsOneWidget);
        expect(find.byKey(const Key('boton-entregado')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('en curso, paso 2: entregar al cliente y sin soltar', (tester) async {
        await abrirPedido(tester, EstadoPedido.enCamino, tema: tema);
        expect(find.byKey(const Key('destino-cliente')), findsOneWidget);
        expect(find.text('Lucía Rojas'), findsOneWidget);
        expect(find.byKey(const Key('boton-entregado')), findsOneWidget);
        expect(find.byKey(const Key('boton-soltar')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('mis entregas: semana, total, calificación, por día y la lista', (tester) async {
        final repartidor = falso()
          ..misEntregas = Entregas(
            pedidos: [pedidoDeEjemplo(estado: EstadoPedido.entregado, paraNegocio: true)],
            total: 1,
            totalEnvios: 5,
          );
        await abrirVista(tester, repartidor, tema: tema);
        await tester.tap(find.text('Mis entregas'));
        await esperar(tester);
        expect(
          find.descendant(of: find.byKey(const Key('semana-bs')), matching: find.text('Bs 61,00')),
          findsOneWidget,
        );
        expect(find.descendant(of: find.byKey(const Key('total-entregas')), matching: find.text('47')), findsOneWidget);
        expect(find.text('★ 4.9'), findsOneWidget);
        expect(find.byKey(const Key('grafico-por-dia')), findsOneWidget);
        expect(find.text('Mejor día: sábado'), findsOneWidget);
        expect(find.text('Pollos Marta → Calle Libertad 123'), findsOneWidget);
        expect(find.textContaining('2,4 km · efectivo'), findsOneWidget);
        expect(find.text('+Bs 5,00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('con un pedido en curso no deja aceptar otro', (tester) async {
    await abrirVista(tester, falso(actual: pedidoDeEjemplo(estado: EstadoPedido.listo, paraNegocio: true)));
    expect(find.text('Tu pedido en curso'), findsOneWidget);
    final aceptar = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Aceptar pedido').first, matching: find.byType(FilledButton)),
    );
    expect(aceptar.onPressed, isNull);
  });

  // Error encontrado probando a mano: su propia compra no aparecía y parecía un fallo.
  testWidgets('su propio pedido aparece, pero sin "Aceptar"', (tester) async {
    final repartidor = falso()
      ..listaDisponibles = const [
        PedidoDisponible(
          id: 50,
          negocioNombre: 'FarmaSuper',
          direccionEntrega: 'Mi casa',
          costoEnvio: 5,
          total: 30,
          propio: true,
        ),
      ];
    await abrirVista(tester, repartidor);
    expect(find.textContaining('FarmaSuper'), findsOneWidget);
    expect(find.text('Es tu propio pedido: lo llevará otro repartidor.'), findsOneWidget);
    expect(find.byKey(const Key('aceptar-50')), findsNothing);
  });

  testWidgets('si otro repartidor lo aceptó primero, avisa', (tester) async {
    final repartidor = falso()
      ..errorAceptar = ApiException(
        'Datos inválidos',
        statusCode: 422,
        errores: {
          'pedido': ['Otro repartidor ya aceptó este pedido.'],
        },
      );
    await abrirVista(tester, repartidor);
    await tester.tap(find.byKey(const Key('aceptar-42')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Otro repartidor ya aceptó este pedido.'), findsOneWidget);
  });

  testWidgets('pedido disponible: recorrido y tiempo estimado de la API', (tester) async {
    final repartidor = falso()
      ..listaDisponibles = const [
        PedidoDisponible(
          id: 60,
          negocioNombre: 'TechStore SCZ',
          negocioDireccion: 'Av. Monseñor Rivero',
          direccionEntrega: 'Calle Libertad',
          costoEnvio: 12,
          total: 245,
          recorridoKm: 2.8,
          tiempoEstimadoMin: 14,
        ),
      ];
    await abrirVista(tester, repartidor);
    expect(find.text('2,8 km · ~14 min'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('disponible-60')), matching: find.text('Bs 12,00')),
      findsOneWidget,
    );
  });

  testWidgets('meta del día: se toca, se cambia y se guarda (PUT /api/repartidor/meta)', (tester) async {
    final repartidor = falso();
    await abrirVista(tester, repartidor);
    await tester.tap(find.byKey(const Key('editar-meta')));
    await esperar(tester);
    await tester.enterText(find.byKey(const Key('campo-meta')), '0');
    await tester.tap(find.byKey(const Key('guardar-meta')));
    await tester.pump();
    expect(find.text('Escribe un monto entre Bs 1 y Bs 10.000.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-meta')), '200');
    await tester.tap(find.byKey(const Key('guardar-meta')));
    await esperar(tester);
    expect(repartidor.metas, [200]);
    expect(find.text('Meta del día Bs 200,00'), findsOneWidget);

    // Y se puede quitar.
    await tester.tap(find.byKey(const Key('editar-meta')));
    await esperar(tester);
    await tester.tap(find.byKey(const Key('quitar-meta')));
    await esperar(tester);
    expect(repartidor.metas, [200, null]);
    expect(find.text('Ponte una meta del día'), findsOneWidget);
  });

  testWidgets('"Cómo llegar" abre Google Maps con la tienda y, ya recogido, con la casa', (tester) async {
    final abiertos = <Uri>[];
    final repartidor = falso(actual: pedidoDeEjemplo(estado: EstadoPedido.listo, paraNegocio: true));
    await abrirPedido(
      tester,
      EstadoPedido.listo,
      repartidor: repartidor,
      extra: [
        abrirEnlaceProvider.overrideWithValue((uri) async {
          abiertos.add(uri);
          return true;
        }),
      ],
    );
    await tester.tap(find.byKey(const Key('como-llegar')));
    await tester.pump();
    expect(abiertos.single.host, 'www.google.com');
    expect(abiertos.single.path, '/maps/dir/');
    // El pedido de ejemplo no trae la ubicación de la tienda: va por nombre.
    expect(abiertos.single.queryParameters['destination'], 'Pollos Marta');

    // "Ya lo recogí": pasa al paso 2 y "Cómo llegar" va a la casa del cliente.
    await tester.tap(find.byKey(const Key('boton-recogido')));
    await esperar(tester);
    expect(find.byKey(const Key('destino-cliente')), findsOneWidget);
    await tester.tap(find.byKey(const Key('como-llegar')));
    await tester.pump();
    expect(abiertos.last.queryParameters['destination'], 'Calle Libertad 123');
  });

  test('el enlace de "Cómo llegar" usa las coordenadas si las hay', () {
    final uri = enlaceComoLlegar(destino: const Coordenada(-17.78, -63.18), bicicleta: true);
    expect(uri.queryParameters['destination'], '-17.78,-63.18');
    expect(uri.queryParameters['travelmode'], 'bicycling');
    expect(uri.queryParameters['api'], '1');
  });

  group('Entregar con el PIN', () {
    Future<void> abrirPin(WidgetTester tester, RepartidorFalso repartidor) async {
      final router = GoRouter(
        initialLocation: '/repartidor/entregar',
        routes: [
          GoRoute(
            path: '/repartidor/entregar',
            builder: (_, _) => const Scaffold(body: EntregarPinScreen()),
          ),
          GoRoute(
            path: '/inicio',
            builder: (_, _) => const Scaffold(body: Text('inicio')),
          ),
        ],
      );
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: overridesFalsos(usuario: repartidorAprobado, repartidor: repartidor).cast(),
          child: MaterialApp.router(theme: AppTheme.claro, routerConfig: router),
        ),
      );
      await esperar(tester);
    }

    Future<void> marcar(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.byKey(Key('tecla-$d')));
        await tester.pump();
      }
    }

    BotonPrincipal confirmar(WidgetTester tester) =>
        tester.widget<BotonPrincipal>(find.byKey(const Key('confirmar-entrega')));

    testWidgets('cobro con el cambio, teclado y 4 casillas', (tester) async {
      final pedido = pedidoDeEjemplo(estado: EstadoPedido.enCamino, paraNegocio: true);
      final conCambio = Pedido(
        id: pedido.id,
        estado: pedido.estado,
        negocioId: pedido.negocioId,
        negocioNombre: pedido.negocioNombre,
        clienteNombre: 'Sofía V.',
        direccionEntrega: 'Calle Libertad 245',
        subtotal: 240,
        costoEnvio: 5,
        tarifaServicio: 0,
        total: 245,
        metodoPago: 'efectivo',
        pagaCon: 300,
        cambio: 55,
      );
      await abrirPin(tester, falso(actual: conCambio));

      expect(find.text('Cobra Bs 245,00 en efectivo'), findsOneWidget);
      expect(find.text('Paga con Bs 300,00 · dale Bs 55,00 de cambio'), findsOneWidget);
      expect(find.text('Pide el código al cliente'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('casilla-$i')), findsOneWidget);
      }
      expect(confirmar(tester).onPressed, isNull);
      await marcar(tester, '48219'); // el quinto número no entra
      expect(find.descendant(of: find.byKey(const Key('casilla-3')), matching: find.text('1')), findsOneWidget);
      expect(confirmar(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('tecla-borrar')));
      await tester.pump();
      expect(confirmar(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PIN equivocado: avisa y lo vuelve a pedir; el correcto lo entrega', (tester) async {
      final repartidor = falso(actual: pedidoDeEjemplo(estado: EstadoPedido.enCamino, paraNegocio: true));
      await abrirPin(tester, repartidor);

      await marcar(tester, '1111');
      await tester.tap(find.byKey(const Key('confirmar-entrega')));
      await esperar(tester);
      expect(repartidor.pinesProbados, ['1111']);
      expect(find.text('El PIN no coincide. Pídeselo de nuevo al cliente.'), findsOneWidget);
      expect(confirmar(tester).onPressed, isNull); // se borró

      await marcar(tester, '4821');
      await tester.tap(find.byKey(const Key('confirmar-entrega')));
      await esperar(tester);
      expect(repartidor.pinesProbados, ['1111', '4821']);
      expect(find.text('inicio'), findsOneWidget);
    });

    test('textos del cobro', () {
      Pedido p({String metodo = 'efectivo', double? pagaCon, double? cambio}) => Pedido(
        id: 1,
        estado: EstadoPedido.enCamino,
        negocioId: 1,
        negocioNombre: 'X',
        direccionEntrega: 'Y',
        subtotal: 20,
        costoEnvio: 5,
        tarifaServicio: 0,
        total: 25,
        metodoPago: metodo,
        pagaCon: pagaCon,
        cambio: cambio,
      );
      expect(textoCobro(p(metodo: 'qr')).titulo, 'Ya pagó con QR');
      expect(textoCobro(p()).detalle, 'No dijo con cuánto paga: lleva cambio');
      expect(textoCobro(p(pagaCon: 25, cambio: 0)).detalle, 'Paga justo, sin cambio');
      expect(textoCobro(p(pagaCon: 50, cambio: 25)).detalle, 'Paga con Bs 50,00 · dale Bs 25,00 de cambio');
    });
  });
}
