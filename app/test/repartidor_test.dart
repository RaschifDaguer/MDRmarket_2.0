import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/comerciante/domain/documento_subido.dart';
import 'package:mdrmarket/features/cuenta/presentation/cuenta_view.dart';
import 'package:mdrmarket/features/inicio/presentation/vistas/inicio_repartidor.dart';
import 'package:mdrmarket/features/perfil/domain/faltante.dart';
import 'package:mdrmarket/features/repartidor/domain/repartidor.dart';
import 'package:mdrmarket/features/repartidor/presentation/registrar_repartidor_screen.dart';
import 'package:mdrmarket/features/repartidor/presentation/revision_repartidor.dart';

import 'falsos.dart';

/// Registro de repartidor en pasos, "En revisión" e invitación desde la vista
/// cliente, con datos falsos: no usan internet.
void main() {
  final placa = find.byKey(const Key('campo-placa'));
  final ruat = find.byKey(const Key('campo-ruat'));

  Future<void> tocar(WidgetTester tester, Finder boton) async {
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pump(const Duration(seconds: 1));
  }

  /// Abre el registro y pasa al paso 2 (el vehículo).
  Future<void> abrirPaso2(WidgetTester tester, {RepartidorFalso? repartidor}) async {
    await abrirConFalsos(
      tester,
      const RegistrarRepartidorScreen(),
      overrides: overridesFalsos(usuario: cliente, repartidor: repartidor),
    );
    await tocar(tester, find.byKey(const Key('siguiente-vehiculo')));
  }

  Future<void> grupo(WidgetTester tester, int g) => tocar(tester, find.byKey(Key('grupo-$g')));

  group('Quiero ser repartidor (en pasos)', () {
    testWidgets('paso 1 de 3: tus datos y qué fotos se van a pedir', (tester) async {
      await abrirConFalsos(tester, const RegistrarRepartidorScreen(), overrides: overridesFalsos(usuario: cliente));
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Tus datos'), findsOneWidget);
      expect(find.textContaining('Después te pediremos fotos'), findsOneWidget);
      expect(placa, findsNothing);
      await tocar(tester, find.byKey(const Key('siguiente-vehiculo')));
      expect(find.text('Paso 2 de 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paso 2: los vehículos en 3 grupos', (tester) async {
      await abrirPaso2(tester);
      expect(find.text('¿Con qué vas a repartir?'), findsOneWidget);
      expect(find.text('Moto o bicicleta'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Camioneta o camión'), findsOneWidget);
      expect(find.text('Pedidos: Liviano'), findsOneWidget);
      expect(find.text('Pedidos: Mediano y Grande'), findsOneWidget);
      expect(placa, findsNothing); // hasta elegir

      // Moto o bicicleta: se elige cuál.
      await grupo(tester, 0);
      expect(find.byKey(const Key('tipo-moto')), findsOneWidget);
      expect(find.byKey(const Key('tipo-bicicleta')), findsOneWidget);
      // Auto: un solo tipo, queda elegido y pide placa y RUAT.
      await grupo(tester, 1);
      expect(find.byKey(const Key('tipo-moto')), findsNothing);
      expect(placa, findsOneWidget);
      expect(ruat, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con moto pide placa y RUAT', (tester) async {
      await abrirPaso2(tester);
      await grupo(tester, 0);
      await tocar(tester, find.byKey(const Key('tipo-moto')));
      expect(placa, findsOneWidget);
      expect(ruat, findsOneWidget);

      // Sin llenarlos no se envía.
      await tocar(tester, find.byKey(const Key('siguiente-documentos')));
      expect(find.text('Escribe la placa del vehículo.'), findsOneWidget);
      expect(find.text('Escribe el número de RUAT del vehículo.'), findsOneWidget);
    });

    testWidgets('con bicicleta no pide placa ni RUAT', (tester) async {
      await abrirPaso2(tester, repartidor: RepartidorFalso());
      await grupo(tester, 0);
      await tocar(tester, find.byKey(const Key('tipo-bicicleta')));
      expect(placa, findsNothing);
      expect(ruat, findsNothing);
      expect(find.text('Tu bicicleta no necesita placa, RUAT ni licencia.'), findsOneWidget);
    });

    testWidgets('sin elegir el tipo, avisa y no envía; "Atrás" vuelve al paso 1', (tester) async {
      final repartidor = RepartidorFalso();
      await abrirPaso2(tester, repartidor: repartidor);
      await tocar(tester, find.byKey(const Key('siguiente-documentos')));
      expect(find.text('Elige el tipo de vehículo.'), findsOneWidget);
      expect(repartidor.solicitudes, 0);
      // En Moto o bicicleta, sin elegir cuál, tampoco.
      await grupo(tester, 0);
      await tocar(tester, find.byKey(const Key('siguiente-documentos')));
      expect(find.text('Elige el tipo de vehículo.'), findsOneWidget);

      await tocar(tester, find.byKey(const Key('paso-atras')));
      expect(find.text('Paso 1 de 3'), findsOneWidget);
    });

    testWidgets('envía la solicitud con el vehículo (paso 2 → documentos)', (tester) async {
      final repartidor = RepartidorFalso();
      await abrirPaso2(tester, repartidor: repartidor);
      await grupo(tester, 0);
      await tocar(tester, find.byKey(const Key('tipo-moto')));
      await tester.enterText(placa, '2345-xkd');
      await tester.enterText(ruat, 'R-9');
      await tocar(tester, find.byKey(const Key('siguiente-documentos')));
      expect(repartidor.solicitudes, 1);
      expect(repartidor.vehiculos.single.tipoVehiculoId, 1); // la moto
      expect(repartidor.vehiculos.single.placa, '2345-xkd');
    });

    testWidgets('el error de la API sale debajo del campo', (tester) async {
      final repartidor = RepartidorFalso(
        errorVehiculo: ApiException(
          'Esa placa ya está registrada.',
          statusCode: 422,
          errores: {
            'placa': ['Esa placa ya está registrada.'],
          },
        ),
      );
      await abrirPaso2(tester, repartidor: repartidor);
      await grupo(tester, 0);
      await tocar(tester, find.byKey(const Key('tipo-moto')));
      await tester.enterText(placa, '1234-abc');
      await tester.enterText(ruat, 'R-1');
      await tocar(tester, find.byKey(const Key('siguiente-documentos')));

      expect(find.text('Esa placa ya está registrada.'), findsOneWidget);
      expect(repartidor.solicitudes, 1);

      // Al corregir y reintentar, no vuelve a pedir el perfil (ya se creó).
      await tocar(tester, find.byKey(const Key('siguiente-documentos')));
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
      await abrirConFalsos(
        tester,
        const RegistrarRepartidorScreen(),
        overrides: overridesFalsos(usuario: cliente, repartidor: repartidor),
      );
      expect(find.text('Tu solicitud no fue aprobada'), findsOneWidget);
      expect(find.text('La placa no coincide con la foto'), findsOneWidget);
      expect(find.text('Moto · 1234-ABC'), findsOneWidget);
      expect(find.text('Volver a enviar'), findsOneWidget);
      // Un solo vehículo: no ofrece elegir otro.
      expect(find.byKey(const Key('grupo-0')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Cuenta del cliente (Tus vistas)', () {
    testWidgets('invita a repartir si no es repartidor', (tester) async {
      await abrirConFalsos(
        tester,
        const CuentaView(usuario: cliente),
        overrides: overridesFalsos(usuario: cliente),
      );
      expect(find.text('Quiero repartir'), findsOneWidget);
      expect(find.text('Gana dinero llevando pedidos'), findsOneWidget);
      expect(find.text('¿Tienes un negocio?'), findsOneWidget); // la del negocio sigue igual
    });

    testWidgets('no la muestra si ya es repartidor', (tester) async {
      await abrirConFalsos(
        tester,
        const CuentaView(usuario: repartidorEnRevision),
        overrides: overridesFalsos(usuario: repartidorEnRevision),
      );
      expect(find.text('Quiero repartir'), findsNothing);
      expect(find.text('Repartir'), findsOneWidget); // ya tiene la vista: la abre
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
      await abrirConFalsos(
        tester,
        const CuentaView(usuario: rechazado),
        overrides: overridesFalsos(usuario: rechazado),
      );
      expect(find.text('Tu solicitud no fue aprobada: mira el motivo'), findsOneWidget);
    });
  });

  // Lo que subió: carnet aprobado, selfie en revisión, RUAT rechazado (con su observación).
  const subidos = [
    DocumentoSubido(
      id: 3,
      tipo: 'ruat',
      nombre: 'RUAT del vehículo',
      estado: 'rechazado',
      observacion: 'Está borroso',
      vehiculoId: 4,
    ),
    DocumentoSubido(id: 2, tipo: 'selfie', nombre: 'Foto de perfil', estado: 'pendiente'),
    DocumentoSubido(id: 1, tipo: 'ci_anverso', nombre: 'Carnet (frente)', estado: 'aprobado'),
    // Uno de su negocio no cuenta aquí.
    DocumentoSubido(id: 9, tipo: 'nit', nombre: 'NIT', estado: 'aprobado', negocioId: 5),
  ];
  // Lo que falta (la API ya incluye el RUAT rechazado y pide el SOAT porque la moto tiene placa).
  const faltan = [
    Faltante(codigo: 'documento.ruat:vehiculo4', texto: 'Foto: RUAT del vehículo', documento: 'ruat', vehiculoId: 4),
    Faltante(codigo: 'documento.soat:vehiculo4', texto: 'Foto: SOAT vigente', documento: 'soat', vehiculoId: 4),
  ];

  test('en revisión: une lo que subió con lo que falta', () {
    final filas = FilaDocumento.armar(subidos, faltan);
    expect(
      [for (final f in filas) (f.titulo, f.estado)],
      [
        ('RUAT del vehículo', EstadoDocumento.rechazado),
        ('Foto: SOAT vigente', EstadoDocumento.falta),
        ('Foto de perfil', EstadoDocumento.enRevision),
        ('Carnet (frente)', EstadoDocumento.aprobado),
      ],
    );
    expect(filas.first.observacion, 'Está borroso');
    expect(filas.first.faltante?.vehiculoId, 4);
  });

  test('en revisión: sin placa no hay SOAT (la API no lo pide)', () {
    final filas = FilaDocumento.armar(const [], const [
      Faltante(codigo: 'documento.ci_anverso', texto: 'Foto: Carnet', documento: 'ci_anverso'),
    ]);
    expect(filas.where((f) => f.titulo.contains('SOAT')), isEmpty);
  });

  for (final (nombre, tema) in [('claro', AppTheme.claro), ('oscuro', AppTheme.oscuro)]) {
    group('Tema $nombre', () {
      testWidgets('la pantalla de registro se dibuja', (tester) async {
        await abrirConFalsos(
          tester,
          const RegistrarRepartidorScreen(),
          overrides: overridesFalsos(usuario: cliente),
          tema: tema,
        );
        expect(find.text('Quiero ser repartidor'), findsOneWidget);
        await tocar(tester, find.byKey(const Key('siguiente-vehiculo')));
        await grupo(tester, 1);
        expect(placa, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('en revisión: cada documento con su estado y "Subir" o "Volver a subir"', (tester) async {
        await abrirConFalsos(
          tester,
          const InicioRepartidor(usuario: repartidorEnRevision),
          overrides: overridesFalsos(usuario: repartidorEnRevision, faltantes: faltan, documentos: subidos),
          tema: tema,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Estamos revisando tus datos'), findsOneWidget);
        expect(find.textContaining('2 de 4 documentos'), findsOneWidget);
        expect(find.text('Rechazado · Está borroso'), findsOneWidget);
        expect(find.text('Volver a subir'), findsOneWidget);
        expect(find.text('Falta subir'), findsOneWidget);
        expect(find.text('Subir'), findsOneWidget);
        expect(find.text('En revisión'), findsOneWidget);
        expect(find.text('Aprobado'), findsOneWidget);
        expect(find.text('NIT'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('en revisión, con todo subido', (tester) async {
        await abrirConFalsos(
          tester,
          const InicioRepartidor(usuario: repartidorEnRevision),
          overrides: overridesFalsos(usuario: repartidorEnRevision, documentos: subidos.sublist(1)),
          tema: tema,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('2 de 2 documentos'), findsOneWidget);
        expect(find.textContaining('te avisa cuando puedas repartir'), findsOneWidget);
        expect(find.text('Subir'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
