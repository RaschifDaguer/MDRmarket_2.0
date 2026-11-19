import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/app.dart';
import 'package:mdrmarket/core/router/app_router.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/auth/presentation/registro_screen.dart';
import 'package:mdrmarket/features/carrito/presentation/carrito_controller.dart';
import 'package:mdrmarket/features/catalogo/domain/producto.dart';
import 'package:mdrmarket/features/catalogo/domain/categoria.dart';
import 'package:mdrmarket/features/catalogo/presentation/widgets/tarjetas_catalogo.dart';
import 'package:mdrmarket/features/comerciante/domain/mi_producto.dart';
import 'package:mdrmarket/features/comerciante/domain/negocio.dart';
import 'package:mdrmarket/features/comerciante/presentation/producto_form_screen.dart';
import 'package:mdrmarket/features/comerciante/presentation/registrar_negocio_screen.dart';
import 'package:mdrmarket/features/repartidor/presentation/entregar_pin_screen.dart';
import 'package:mdrmarket/features/terminos/data/terminos_repository.dart';
import 'package:mdrmarket/features/terminos/presentation/terminos_screen.dart';

import 'falsos.dart';

/// Términos y condiciones (mayor de 18), bebidas alcohólicas y permisos de
/// licorerías y farmacias, con datos falsos (sin internet).
void main() {
  const cerveza = Producto(
    id: 30,
    nombre: 'Cerveza Paceña 620 ml',
    precio: 15,
    precioFinal: 15,
    stock: 24,
    soloMayores: true,
    negocio: polleria,
  );

  const terminos = Terminos(
    version: '2026-11-18',
    actualizado: '18 de noviembre de 2026',
    declaracion: 'Declaro que soy mayor de 18 años y acepto los Términos y condiciones de MDR Market.',
    resumen: 'Para usarla tienes que ser mayor de 18 años.',
    secciones: [
      SeccionTerminos(titulo: '5. Bebidas alcohólicas', parrafos: ['Solo a mayores de 18 años.']),
    ],
  );

  Future<void> abrirApp(WidgetTester tester, List overrides) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null, overrides: overrides.cast(), child: const MdrMarketApp()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('las bebidas alcohólicas llevan la etiqueta +18', (tester) async {
    await abrirConFalsos(
      tester,
      Center(child: SizedBox(width: 200, height: 300, child: TarjetaProducto(producto: cerveza, alTocar: () {}))),
      overrides: overridesFalsos(usuario: cliente),
    );
    expect(find.text('+18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> paso(WidgetTester tester, Finder boton) async {
    await tester.tap(boton);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('comprar alcohol o tabaco: "¿es mayor de edad?" y después la declaración', (tester) async {
    final pedidos = PedidosFalso();
    await abrirApp(tester, overridesFalsos(usuario: cliente, pedidos: pedidos));
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(MdrMarketApp)));
    contenedor.read(carritoProvider.notifier).agregar(cerveza, 2);
    contenedor.read(routerProvider).push('/checkout');
    await esperar(tester);
    expect(find.byKey(const Key('aviso-mayores')), findsOneWidget);
    final hacerPedido = find.textContaining('Hacer pedido');

    // 1. Dice que NO es mayor: se le explica y no se pide nada.
    await paso(tester, hacerPedido);
    expect(find.text('¿Usted es mayor de edad?'), findsOneWidget);
    await paso(tester, find.byKey(const Key('paso1-no')));
    expect(find.textContaining('la venta a menores de 18 años está prohibida'), findsOneWidget);
    await paso(tester, find.text('Entendido'));
    expect(pedidos.creado, isNull);

    // 2. Dice que SÍ, pero no marca la declaración: no puede confirmar.
    await paso(tester, hacerPedido);
    await paso(tester, find.byKey(const Key('paso1-si')));
    expect(find.textContaining('Usted está de acuerdo en realizar la compra'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('paso2-confirmar'))).onPressed, isNull);

    // 3. Marca la declaración y confirma: se pide con las dos confirmaciones.
    await paso(tester, find.byKey(const Key('paso2-casilla')));
    await paso(tester, find.byKey(const Key('paso2-confirmar')));
    await esperar(tester);
    expect(pedidos.creado!.confirmaMayorEdad, isTrue);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('sin bebidas alcohólicas no se pregunta la edad', (tester) async {
    final pedidos = PedidosFalso();
    await abrirApp(tester, overridesFalsos(usuario: cliente, pedidos: pedidos));
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(MdrMarketApp)));
    contenedor.read(carritoProvider.notifier).agregar(pollo, 1);
    contenedor.read(routerProvider).push('/checkout');
    await esperar(tester);

    expect(find.byKey(const Key('aviso-mayores')), findsNothing);
    await tester.tap(find.textContaining('Hacer pedido'));
    await esperar(tester);
    expect(pedidos.creado!.confirmaMayorEdad, isFalse);
    await cerrar(tester);
  });

  testWidgets('crear cuenta exige marcar "soy mayor de 18 y acepto los términos"', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RegistroScreen())));
    Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

    await tester.enterText(campo('Nombre'), 'Lucía');
    await tester.enterText(campo('Apellido'), 'Rojas');
    await tester.tap(find.byKey(const Key('registro-siguiente')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(campo('Número de CI'), '9876543');
    await tester.tap(find.byKey(const Key('registro-siguiente')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(campo('Correo electrónico'), 'lucia@correo.com');
    await tester.enterText(campo('Contraseña'), 'Secreta123');
    await tester.enterText(campo('Repetir contraseña'), 'Secreta123');

    expect(find.byKey(const Key('registro-ver-terminos')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('tienes que ser mayor de 18 años y aceptar los términos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('registro-terminos')));
    await tester.pump();
    expect(find.textContaining('tienes que ser mayor de 18 años y aceptar los términos'), findsNothing);
  });

  testWidgets('una cuenta antigua tiene que aceptar los términos para seguir', (tester) async {
    const antigua = Usuario(
      id: 3,
      nombre: 'Pedro',
      email: 'pedro@correo.com',
      vistas: [Vista.cliente],
      vistaGuardada: 'cliente',
      terminosPendientes: true,
    );
    await abrirApp(tester, [
      ...overridesFalsos(usuario: antigua),
      terminosProvider.overrideWith((ref) async => terminos),
    ]);

    expect(find.byType(TerminosScreen), findsOneWidget);
    expect(find.text('Actualizamos nuestros términos'), findsOneWidget);
    expect(find.text('5. Bebidas alcohólicas'), findsOneWidget);
    // Sin marcar la casilla, el botón no hace nada.
    final boton = tester.widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('terminos-aceptar')), matching: find.byType(FilledButton)),
    );
    expect(boton.onPressed, isNull);
    await tester.tap(find.byKey(const Key('terminos-casilla')));
    await tester.pump();
    final habilitado = tester.widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('terminos-aceptar')), matching: find.byType(FilledButton)),
    );
    expect(habilitado.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await cerrar(tester);
  });

  testWidgets('registrar una licorería o farmacia muestra los permisos que se piden', (tester) async {
    await abrirConFalsos(
      tester,
      const RegistrarNegocioScreen(),
      overrides: overridesFalsos(usuario: cliente),
      tamano: const Size(390, 2700),
    );

    expect(find.textContaining('SEDES'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('permiso-farmacia')));
    await tester.tap(find.byKey(const Key('permiso-farmacia')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('SEDES'), findsOneWidget);
    expect(find.textContaining('rubro de farmacia'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('permiso-alcohol')));
    await tester.tap(find.byKey(const Key('permiso-alcohol')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Autorización de expendio de bebidas alcohólicas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una farmacia confirma en dos pasos que el medicamento se vende sin receta', (tester) async {
    final miNegocio = MiNegocioFalso();
    const farmacia = Negocio(
      id: 6,
      nombre: 'Farmacia Central',
      estado: EstadoNegocio.aprobado,
      categoria: Categoria(id: 2, nombre: 'Salud y Belleza'),
      esFarmacia: true,
    );
    const paracetamol = MiProducto(id: 40, nombre: 'Paracetamol 500 mg', precio: 8, stock: 50, categoriaId: 201);
    await abrirConFalsos(
      tester,
      const ProductoFormScreen(producto: paracetamol),
      overrides: overridesFalsos(usuario: cliente, negocios: const [farmacia], miNegocio: miNegocio),
      tamano: const Size(390, 1600),
    );
    final guardar = find.widgetWithText(FilledButton, 'Guardar cambios');

    // "No, necesita receta": no se publica.
    await paso(tester, guardar);
    expect(find.text('¿Este producto se vende sin receta médica?'), findsOneWidget);
    await paso(tester, find.byKey(const Key('paso1-no')));
    expect(find.textContaining('no se venden en MDR Market'), findsOneWidget);
    await paso(tester, find.text('Entendido'));
    expect(miNegocio.guardados, isEmpty);

    // "Sí, es de venta libre" + la declaración marcada: se guarda con la confirmación.
    await paso(tester, guardar);
    await paso(tester, find.byKey(const Key('paso1-si')));
    expect(find.textContaining('Usted está publicando un producto que no necesita receta médica'), findsOneWidget);
    await paso(tester, find.byKey(const Key('paso2-casilla')));
    await paso(tester, find.byKey(const Key('paso2-confirmar')));
    await tester.pump(const Duration(seconds: 1));
    expect(miNegocio.guardados.single.$1.confirmaVentaLibre, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el repartidor ve que tiene que pedir el carnet', (tester) async {
    await abrirConFalsos(tester, const Scaffold(body: AvisoCarnet()), overrides: overridesFalsos(usuario: cliente));
    expect(find.text('Pide el carnet de identidad'), findsOneWidget);
  });
}
