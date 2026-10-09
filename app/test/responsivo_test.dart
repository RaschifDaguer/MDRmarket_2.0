import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/auth/presentation/auth_controller.dart';
import 'package:mdrmarket/features/catalogo/data/catalogo_repository.dart';
import 'package:mdrmarket/features/catalogo/domain/categoria.dart';
import 'package:mdrmarket/features/comerciante/data/negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/domain/negocio.dart';
import 'package:mdrmarket/features/comerciante/presentation/registrar_negocio_screen.dart';
import 'package:mdrmarket/features/inicio/presentation/inicio_screen.dart';
import 'package:mdrmarket/features/perfil/data/perfil_repository.dart';
import 'package:mdrmarket/features/perfil/domain/faltante.dart';

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

class _SesionFalsa extends AuthController {
  _SesionFalsa(this._usuario);

  final Usuario _usuario;

  @override
  Future<Usuario?> build() async => _usuario;
}

const _cliente = Usuario(
  id: 1,
  nombre: 'Marta',
  apellido: 'Suárez',
  email: 'marta@correo.com',
  ciNumero: '7654321',
  telefono: '70012345',
  vistas: [Vista.cliente],
  vistaGuardada: 'cliente',
);

const _comerciante = Usuario(
  id: 1,
  nombre: 'Marta',
  apellido: 'Suárez',
  email: 'marta@correo.com',
  ciNumero: '7654321',
  vistas: [Vista.cliente, Vista.comerciante],
  vistaGuardada: 'comerciante',
);

// Sin emojis: en las pruebas no hay fuente de emojis (en el navegador sí se ven).
const _categorias = [
  Categoria(id: 1, nombre: 'Alimentos y Bebidas'),
  Categoria(id: 2, nombre: 'Salud y Belleza'),
];

const _faltaCarnet = [
  Faltante(codigo: 'documento.ci_anverso', texto: 'Foto: Carnet de identidad (anverso)', documento: 'ci_anverso'),
  Faltante(codigo: 'documento.ci_reverso', texto: 'Foto: Carnet de identidad (reverso)', documento: 'ci_reverso'),
];

const _negocio = Negocio(
  id: 5,
  nombre: 'Tienda Marta',
  estado: EstadoNegocio.pendiente,
  categoria: Categoria(id: 1, nombre: 'Alimentos y Bebidas'),
  direccion: 'Av. Busch 1234, entre 2do y 3er anillo',
);

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

  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla,
    Size tamano, {
    required Usuario usuario,
    List<Negocio> negocios = const [],
    List<Faltante> faltantes = const [],
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: _raiz,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authControllerProvider.overrideWith(() => _SesionFalsa(usuario)),
          categoriasProvider.overrideWith((ref) async => _categorias),
          faltantesProvider.overrideWith((ref, rol) async => faltantes),
          misNegociosProvider.overrideWith((ref) async => negocios),
        ],
        child: MaterialApp(theme: AppTheme.claro, debugShowCheckedModeBanner: false, home: pantalla),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
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

  for (final MapEntry(key: dispositivo, value: tamano) in _tamanos.entries) {
    group(dispositivo, () {
      testWidgets('inicio cliente', (tester) async {
        await abrir(tester, const InicioScreen(), tamano, usuario: _cliente);
        expect(find.text('¿Tienes un negocio?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await guardar(tester, '$dispositivo-1-inicio-cliente');
      });

      testWidgets('registrar negocio', (tester) async {
        await abrir(tester, const RegistrarNegocioScreen(), tamano, usuario: _cliente, faltantes: _faltaCarnet);
        expect(find.text('Registrar mi negocio'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await guardar(tester, '$dispositivo-2-registrar-negocio');
      });

      testWidgets('inicio comerciante', (tester) async {
        await abrir(tester, const InicioScreen(), tamano,
            usuario: _comerciante, negocios: const [_negocio], faltantes: _faltaCarnet);
        expect(find.text('Negocio en revisión'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await guardar(tester, '$dispositivo-3-inicio-comerciante');
      });
    });
  }

  testWidgets('formulario completo con errores (celular)', (tester) async {
    // Alto grande para ver el formulario entero en una sola imagen.
    await abrir(tester, const RegistrarNegocioScreen(), const Size(390, 2300),
        usuario: _cliente, faltantes: _faltaCarnet);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar negocio'));
    await tester.pump(const Duration(seconds: 1));
    // Un cuadro más: los errores de los campos aparecen con una animación.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Agrega una foto del negocio.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await guardar(tester, 'celular-4-formulario-con-errores');
  });

  testWidgets('letra grande en celular chico', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await abrir(tester, const InicioScreen(), const Size(360, 740),
        usuario: _comerciante, negocios: const [_negocio], faltantes: _faltaCarnet);
    expect(tester.takeException(), isNull);
    await guardar(tester, 'celular-chico-5-letra-grande');
  });
}
