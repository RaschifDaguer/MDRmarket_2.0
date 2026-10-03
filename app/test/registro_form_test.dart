import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/features/auth/presentation/registro_screen.dart';
import 'package:mdrmarket/features/auth/presentation/widgets/requisitos_password.dart';

/// Pruebas del formulario de registro, sin internet.
void main() {
  group('Reglas de contraseña', () {
    test('rechaza las que no tienen mayúscula, minúscula, número u 8 caracteres', () {
      expect(ReglasPassword.cumple('secreta123'), isFalse); // sin mayúscula
      expect(ReglasPassword.cumple('SECRETA123'), isFalse); // sin minúscula
      expect(ReglasPassword.cumple('SecretaABC'), isFalse); // sin número
      expect(ReglasPassword.cumple('Sec12'), isFalse); // corta
      expect(ReglasPassword.cumple('Secreta123'), isTrue);
      expect(ReglasPassword.cumple('Ñandú2026'), isTrue); // acepta letras con tilde
    });
  });

  Future<void> abrirRegistro(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RegistroScreen())));
  }

  Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

  testWidgets('los requisitos se marcan mientras se escribe la contraseña', (tester) async {
    await abrirRegistro(tester);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.enterText(campo('Contraseña'), 'secreta1');
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3)); // falta la mayúscula

    await tester.enterText(campo('Contraseña'), 'Secreta1');
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
  });

  testWidgets('avisa si las dos contraseñas no coinciden', (tester) async {
    await abrirRegistro(tester);
    await tester.enterText(campo('Nombre'), 'Lucía');
    await tester.enterText(campo('Apellido'), 'Rojas');
    await tester.enterText(campo('Número de CI'), '9876543');
    await tester.enterText(campo('Correo electrónico'), 'lucia@correo.com');
    await tester.enterText(campo('Contraseña'), 'Secreta123');
    await tester.enterText(campo('Repetir contraseña'), 'Secreta124');

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });
}
