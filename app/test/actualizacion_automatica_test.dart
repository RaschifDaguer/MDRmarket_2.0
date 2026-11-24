import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/widgets/actualizacion_automatica.dart';

/// Pantallas que se actualizan solas (sin recargar): cada pocos segundos
/// mientras se ven, en pausa si no se ven, y al volver a la app.
void main() {
  testWidgets('actualiza cada tanto mientras la pantalla se ve', (tester) async {
    var veces = 0;
    await tester.pumpWidget(
      ActualizacionAutomatica(cada: const Duration(seconds: 8), alActualizar: () => veces++, child: const SizedBox()),
    );
    expect(veces, 0);
    await tester.pump(const Duration(seconds: 8));
    expect(veces, 1);
    await tester.pump(const Duration(seconds: 16));
    expect(veces, 3);
    await tester.pumpWidget(const SizedBox()); // se cierra la pantalla: deja de actualizar
    await tester.pump(const Duration(seconds: 30));
    expect(veces, 3);
  });

  testWidgets('en pausa si la pantalla no se ve (ej. otra pestaña)', (tester) async {
    var veces = 0;
    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: ActualizacionAutomatica(
          cada: const Duration(seconds: 8),
          alActualizar: () => veces++,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 24));
    expect(veces, 0);
  });

  testWidgets('en segundo plano no actualiza; al volver a la app, enseguida', (tester) async {
    var veces = 0;
    await tester.pumpWidget(
      ActualizacionAutomatica(cada: const Duration(seconds: 8), alActualizar: () => veces++, child: const SizedBox()),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 24));
    expect(veces, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(veces, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
