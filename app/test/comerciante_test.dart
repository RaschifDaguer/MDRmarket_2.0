import 'package:flutter/material.dart';
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
import 'package:mdrmarket/features/inicio/presentation/vistas/inicio_cliente.dart';
import 'package:mdrmarket/features/inicio/presentation/vistas/inicio_comerciante.dart';
import 'package:mdrmarket/features/perfil/data/perfil_repository.dart';
import 'package:mdrmarket/features/perfil/domain/faltante.dart';

/// Sesión falsa: nunca llama a la API ni usa internet.
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

const _categorias = [
  Categoria(id: 1, nombre: 'Alimentos y Bebidas', icono: '🍔'),
  Categoria(id: 2, nombre: 'Farmacia', icono: '💊'),
];

const _faltaCarnet = [
  Faltante(codigo: 'documento.ci_anverso', texto: 'Foto: Carnet de identidad (anverso)', documento: 'ci_anverso'),
  Faltante(codigo: 'documento.ci_reverso', texto: 'Foto: Carnet de identidad (reverso)', documento: 'ci_reverso'),
];

const _tiendaMarta = Negocio(
  id: 7,
  nombre: 'Tienda Marta',
  estado: EstadoNegocio.pendiente,
  categoria: Categoria(id: 1, nombre: 'Alimentos y Bebidas', icono: '🍔'),
  direccion: 'Av. Busch 1234, 3er anillo',
);

void main() {
  /// Abre [pantalla] en tamaño de celular, con datos falsos en lugar de la API.
  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla, {
    Usuario usuario = _cliente,
    List<Faltante> faltantes = const [],
    List<Negocio> negocios = const [],
    ThemeData? tema,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authControllerProvider.overrideWith(() => _SesionFalsa(usuario)),
        categoriasProvider.overrideWith((ref) async => _categorias),
        faltantesProvider.overrideWith((ref, rol) async => faltantes),
        misNegociosProvider.overrideWith((ref) async => negocios),
      ],
      child: MaterialApp(theme: tema ?? AppTheme.claro, home: Scaffold(body: pantalla)),
    ));
    // Deja terminar las cargas y las animaciones de entrada.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  group('Registrar mi negocio', () {
    testWidgets('sin datos, avisa todo lo que falta y no envía', (tester) async {
      await abrir(tester, const RegistrarNegocioScreen(), faltantes: _faltaCarnet);

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
      await abrir(tester, const RegistrarNegocioScreen(), faltantes: _faltaCarnet);
      expect(find.text('Tu carnet de identidad'), findsOneWidget);
    });

    testWidgets('no pide el carnet si ya lo subió', (tester) async {
      await abrir(tester, const RegistrarNegocioScreen());
      expect(find.text('Tu carnet de identidad'), findsNothing);
      // NIT y nombre para facturas (razón social) son opcionales.
      expect(find.text('Datos para facturas'), findsOneWidget);
      expect(find.text('Nombre para facturas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra los rubros de la API', (tester) async {
      await abrir(tester, const RegistrarNegocioScreen());
      await tester.tap(find.text('Rubro'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('💊 Farmacia'), findsWidgets);
    });

    testWidgets('sin mapa, ofrece el GPS', (tester) async {
      await abrir(tester, const RegistrarNegocioScreen());
      expect(find.text('Usar mi ubicación'), findsOneWidget);
    });
  });

  group('Vista cliente', () {
    testWidgets('invita a registrar un negocio si no tiene', (tester) async {
      await abrir(tester, const InicioCliente(usuario: _cliente));
      expect(find.text('¿Tienes un negocio?'), findsOneWidget);
    });

    testWidgets('no lo muestra si ya es comerciante', (tester) async {
      await abrir(tester, const InicioCliente(usuario: _comerciante), usuario: _comerciante);
      expect(find.text('¿Tienes un negocio?'), findsNothing);
    });
  });

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Vista comerciante (tema $nombre)', () {
      testWidgets('negocio en revisión con lo que falta', (tester) async {
        await abrir(
          tester,
          const InicioComerciante(usuario: _comerciante),
          usuario: _comerciante,
          negocios: const [_tiendaMarta],
          faltantes: _faltaCarnet,
          tema: tema,
        );
        expect(find.text('Negocio en revisión'), findsOneWidget);
        expect(find.text('Tienda Marta'), findsOneWidget);
        expect(find.text('🍔 Alimentos y Bebidas'), findsOneWidget);
        expect(find.text('Para activar tu negocio te falta'), findsOneWidget);
        expect(find.text('Subir'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('negocio activo y completo: sin lista de faltantes', (tester) async {
        const activo = Negocio(id: 7, nombre: 'Tienda Marta', estado: EstadoNegocio.aprobado);
        await abrir(
          tester,
          const InicioComerciante(usuario: _comerciante),
          usuario: _comerciante,
          negocios: const [activo],
          tema: tema,
        );
        expect(find.text('¡Tu negocio está activo!'), findsOneWidget);
        expect(find.text('Para activar tu negocio te falta'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('sin negocio: botón para registrarlo', (tester) async {
        await abrir(tester, const InicioComerciante(usuario: _comerciante), usuario: _comerciante, tema: tema);
        expect(find.text('Todavía no tienes un negocio'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Registrar mi negocio'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
