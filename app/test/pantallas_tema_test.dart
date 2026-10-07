import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/auth/presentation/auth_controller.dart';
import 'package:mdrmarket/features/auth/presentation/login_screen.dart';
import 'package:mdrmarket/features/auth/presentation/registro_screen.dart';
import 'package:mdrmarket/features/auth/presentation/splash_screen.dart';
import 'package:mdrmarket/features/inicio/presentation/inicio_screen.dart';

/// Sesión falsa: nunca llama a la API ni usa internet.
class _SesionFalsa extends AuthController {
  _SesionFalsa(this._resultado);

  final Future<Usuario?> Function() _resultado;

  @override
  Future<Usuario?> build() => _resultado();
}

const _usuario = Usuario(
  id: 1,
  nombre: 'Lucía',
  apellido: 'Rojas',
  email: 'lucia@correo.com',
  vistas: [Vista.cliente, Vista.repartidor, Vista.comerciante],
  vistaGuardada: 'repartidor',
  estadoRepartidor: 'pendiente',
);

/// Pruebas de que cada pantalla se dibuja sin errores (ni desbordes) con el
/// tema claro y el oscuro, en tamaño de celular.
void main() {
  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla,
    ThemeData tema, {
    Future<Usuario?> Function()? sesion,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        if (sesion != null) authControllerProvider.overrideWith(() => _SesionFalsa(sesion)),
      ],
      child: MaterialApp(theme: tema, home: pantalla),
    ));
    await tester.pump();
  }

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Tema $nombre', () {
      testWidgets('el login se dibuja', (tester) async {
        await abrir(tester, const LoginScreen(), tema);
        expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
        expect(find.text('Correo electrónico'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el registro se dibuja', (tester) async {
        await abrir(tester, const RegistroScreen(), tema);
        expect(find.widgetWithText(FilledButton, 'Crear cuenta'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el arranque se dibuja mientras revisa la sesión', (tester) async {
        // Un Future que nunca termina = "todavía revisando".
        await abrir(tester, const SplashScreen(), tema, sesion: () => Completer<Usuario?>().future);
        expect(find.text('MDR Market'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el arranque muestra el error y "Reintentar"', (tester) async {
        await abrir(tester, const SplashScreen(), tema,
            sesion: () => Future.error(Exception('Sin conexión')));
        await tester.pump();
        expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el inicio se dibuja con el selector de vistas', (tester) async {
        await abrir(tester, const InicioScreen(), tema, sesion: () async => _usuario);
        await tester.pump();
        expect(find.text('Hola, Lucía'), findsOneWidget);
        expect(find.byKey(const Key('boton-cambiar-vista')), findsOneWidget);
        expect(find.text('Solicitud en revisión'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
