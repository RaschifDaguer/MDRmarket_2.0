import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // Sin reintentos automáticos: si el servidor no responde, la pantalla
      // de inicio muestra el error con un botón "Reintentar".
      retry: (_, _) => null,
      child: const MdrMarketApp(),
    ),
  );
}
