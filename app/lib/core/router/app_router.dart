import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/registro_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/inicio/presentation/inicio_screen.dart';

/// Rutas de la app. Lleva solo a cada pantalla según la sesión:
/// - revisando sesión o servidor caído -> /splash
/// - sin sesión                       -> /login (o /registro)
/// - con sesión                       -> /inicio
final routerProvider = Provider<GoRouter>((ref) {
  final cambiosDeSesion = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => cambiosDeSesion.value++);
  ref.onDispose(cambiosDeSesion.dispose);

  const rutasPublicas = {'/login', '/registro'};

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: cambiosDeSesion,
    redirect: (context, state) {
      final ruta = state.matchedLocation;
      final sesion = ref.read(authControllerProvider);

      if (sesion is! AsyncData) return ruta == '/splash' ? null : '/splash';

      final conectado = sesion.value != null;
      if (!conectado) return rutasPublicas.contains(ruta) ? null : '/login';
      if (rutasPublicas.contains(ruta) || ruta == '/splash') return '/inicio';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/registro', builder: (_, _) => const RegistroScreen()),
      GoRoute(path: '/inicio', builder: (_, _) => const InicioScreen()),
    ],
  );
});
