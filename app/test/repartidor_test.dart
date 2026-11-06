import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/inicio/presentation/vistas/inicio_cliente.dart';
import 'package:mdrmarket/features/inicio/presentation/vistas/inicio_repartidor.dart';
import 'package:mdrmarket/features/repartidor/domain/repartidor.dart';
import 'package:mdrmarket/features/repartidor/presentation/registrar_repartidor_screen.dart';

import 'falsos.dart';

/// Registro de repartidor (pantalla, vista en revisión e invitación desde la
/// vista cliente), con datos falsos: no usan internet.
void main() {
  final placa = find.byKey(const Key('campo-placa'));
  final ruat = find.byKey(const Key('campo-ruat'));
  final enviar = find.widgetWithText(FilledButton, 'Enviar solicitud');

  Future<void> elegir(WidgetTester tester, String codigo) async {
    final tarjeta = find.byKey(Key('tipo-$codigo'));
    await tester.ensureVisible(tarjeta);
    await tester.tap(tarjeta);
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tocarEnviar(WidgetTester tester) async {
    await tester.ensureVisible(enviar);
    await tester.tap(enviar);
    await tester.pump(const Duration(seconds: 1));
  }

  group('Quiero ser repartidor', () {
    testWidgets('muestra los 5 tipos de vehículo', (tester) async {
      await abrirConFalsos(tester, const RegistrarRepartidorScreen(), overrides: overridesFalsos(usuario: cliente));
      for (final nombre in ['Moto', 'Bicicleta', 'Auto', 'Camioneta', 'Camión']) {
        expect(find.text(nombre), findsOneWidget);
      }
      expect(placa, findsNothing); // hasta elegir el tipo
      expect(tester.takeException(), isNull);
    });

    testWidgets('con moto pide placa y RUAT', (tester) async {
      await abrirConFalsos(tester, const RegistrarRepartidorScreen(), overrides: overridesFalsos(usuario: cliente));
      await elegir(tester, 'moto');
      expect(placa, findsOneWidget);
      expect(ruat, findsOneWidget);
      expect(find.textContaining('tu licencia de conducir'), findsOneWidget);

      // Sin llenarlos no se envía.
      await tocarEnviar(tester);
      expect(find.text('Escribe la placa del vehículo.'), findsOneWidget);
      expect(find.text('Escribe el número de RUAT del vehículo.'), findsOneWidget);
    });

    testWidgets('con bicicleta no pide placa ni RUAT', (tester) async {
      final repartidor = RepartidorFalso();
      await abrirConFalsos(tester, const RegistrarRepartidorScreen(),
          overrides: overridesFalsos(usuario: cliente, repartidor: repartidor));
      await elegir(tester, 'moto');
      await elegir(tester, 'bicicleta');
      expect(placa, findsNothing);
      expect(ruat, findsNothing);
      expect(find.text('Tu bicicleta no necesita placa, RUAT ni licencia.'), findsOneWidget);
      expect(find.textContaining('licencia de conducir'), findsNothing);
    });

    testWidgets('sin elegir el tipo, avisa y no envía', (tester) async {
      final repartidor = RepartidorFalso();
      await abrirConFalsos(tester, const RegistrarRepartidorScreen(),
          overrides: overridesFalsos(usuario: cliente, repartidor: repartidor));
      await tocarEnviar(tester);
      expect(find.text('Elige el tipo de vehículo.'), findsOneWidget);
      expect(repartidor.solicitudes, 0);
    });

    testWidgets('el error de la API sale debajo del campo', (tester) async {
      final repartidor = RepartidorFalso(
        errorVehiculo: ApiException('Esa placa ya está registrada.', statusCode: 422, errores: {
          'placa': ['Esa placa ya está registrada.'],
        }),
      );
      await abrirConFalsos(tester, const RegistrarRepartidorScreen(),
          overrides: overridesFalsos(usuario: cliente, repartidor: repartidor));
      await elegir(tester, 'moto');
      await tester.enterText(placa, '1234-abc');
      await tester.enterText(ruat, 'R-1');
      await tocarEnviar(tester);

      expect(find.text('Esa placa ya está registrada.'), findsOneWidget);
      expect(repartidor.solicitudes, 1);

      // Al corregir y reintentar, no vuelve a pedir el perfil (ya se creó).
      await tocarEnviar(tester);
      expect(repartidor.solicitudes, 1);
    });

    testWidgets('si lo rechazaron, muestra el motivo y "Volver a enviar"', (tester) async {
      final repartidor = RepartidorFalso(
        perfil: const PerfilRepartidor(
          estado: 'rechazado',
          motivoRechazo: 'La placa no coincide con la foto',
          vehiculos: [Vehiculo(id: 4, tipoCodigo: 'moto', tipoNombre: 'Moto', placa: '1234-ABC', estado: 'rechazado')],
        ),
      );
      await abrirConFalsos(tester, const RegistrarRepartidorScreen(),
          overrides: overridesFalsos(usuario: cliente, repartidor: repartidor));
      expect(find.text('Tu solicitud no fue aprobada'), findsOneWidget);
      expect(find.text('La placa no coincide con la foto'), findsOneWidget);
      expect(find.text('Moto · 1234-ABC'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Volver a enviar'), findsOneWidget);
      // Un solo vehículo: no ofrece elegir otro.
      expect(find.byKey(const Key('tipo-moto')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Vista cliente', () {
    testWidgets('invita a repartir si no es repartidor', (tester) async {
      await abrirConFalsos(tester, const InicioCliente(usuario: cliente), overrides: overridesFalsos(usuario: cliente));
      expect(find.text('¿Quieres repartir?'), findsOneWidget);
      expect(find.text('Registrarme'), findsOneWidget);
      expect(find.text('¿Tienes un negocio?'), findsOneWidget); // la del negocio sigue igual
    });

    testWidgets('no la muestra si ya es repartidor', (tester) async {
      await abrirConFalsos(tester, const InicioCliente(usuario: repartidorEnRevision),
          overrides: overridesFalsos(usuario: repartidorEnRevision));
      expect(find.text('¿Quieres repartir?'), findsNothing);
    });

    testWidgets('si lo rechazaron, invita a revisar', (tester) async {
      const rechazado = Usuario(
        id: 1,
        nombre: 'Diego',
        email: 'diego@correo.com',
        vistas: [Vista.cliente],
        vistaGuardada: 'cliente',
        estadoRepartidor: 'rechazado',
      );
      await abrirConFalsos(tester, const InicioCliente(usuario: rechazado), overrides: overridesFalsos(usuario: rechazado));
      expect(find.text('Tu solicitud de repartidor no fue aprobada'), findsOneWidget);
      expect(find.text('Revisar'), findsOneWidget);
    });
  });

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Tema $nombre', () {
      testWidgets('la pantalla de registro se dibuja', (tester) async {
        await abrirConFalsos(tester, const RegistrarRepartidorScreen(),
            overrides: overridesFalsos(usuario: cliente), tema: tema);
        await elegir(tester, 'moto');
        expect(find.text('Quiero ser repartidor'), findsOneWidget);
        expect(placa, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('en revisión, con lo que falta subir', (tester) async {
        await abrirConFalsos(tester, const InicioRepartidor(usuario: repartidorEnRevision),
            overrides: overridesFalsos(usuario: repartidorEnRevision, faltantes: faltaMoto), tema: tema);
        expect(find.text('Solicitud en revisión'), findsOneWidget);
        expect(find.text('Te falta subir…'), findsOneWidget);
        expect(find.text('Subir'), findsNWidgets(faltaMoto.length));
        expect(find.text('Foto de la placa'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('en revisión, con todo subido', (tester) async {
        await abrirConFalsos(tester, const InicioRepartidor(usuario: repartidorEnRevision),
            overrides: overridesFalsos(usuario: repartidorEnRevision), tema: tema);
        expect(find.text('Solicitud en revisión'), findsOneWidget);
        expect(find.text('Ya enviaste todo'), findsOneWidget);
        expect(find.text('Te falta subir…'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
