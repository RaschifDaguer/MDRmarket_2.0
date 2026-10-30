import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/registro_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/carrito/presentation/carrito_screen.dart';
import '../../features/catalogo/presentation/producto_screen.dart';
import '../../features/catalogo/presentation/tienda_screen.dart';
import '../../features/comerciante/domain/mi_producto.dart';
import '../../features/comerciante/presentation/calificaciones_screen.dart';
import '../../features/comerciante/presentation/horario_screen.dart';
import '../../features/comerciante/presentation/pedido_negocio_screen.dart';
import '../../features/comerciante/presentation/perfil_negocio_screen.dart';
import '../../features/comerciante/presentation/producto_form_screen.dart';
import '../../features/comerciante/presentation/registrar_negocio_screen.dart';
import '../../features/comerciante/presentation/registros_screen.dart';
import '../../features/inicio/presentation/inicio_screen.dart';
import '../../features/pedidos/presentation/checkout_screen.dart';
import '../../features/pedidos/presentation/pedido_screen.dart';
import '../../features/repartidor/presentation/pedido_actual_screen.dart';
import '../../features/repartidor/presentation/registrar_repartidor_screen.dart';

/// Número de la ruta (ej. /producto/12 → 12).
int _id(GoRouterState estado) => int.tryParse(estado.pathParameters['id'] ?? '') ?? 0;

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
      GoRoute(path: '/registrar-negocio', builder: (_, _) => const RegistrarNegocioScreen()),
      GoRoute(path: '/registrar-repartidor', builder: (_, _) => const RegistrarRepartidorScreen()),

      // Repartidor (el pedido que lleva)
      GoRoute(path: '/repartidor/pedido', builder: (_, _) => const PedidoActualScreen()),

      // Cliente
      GoRoute(path: '/producto/:id', builder: (_, s) => ProductoScreen(productoId: _id(s))),
      GoRoute(path: '/tienda/:id', builder: (_, s) => TiendaScreen(tiendaId: _id(s))),
      GoRoute(path: '/carrito', builder: (_, _) => const CarritoScreen()),
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(path: '/pedido/:id', builder: (_, s) => PedidoScreen(pedidoId: _id(s))),

      // Comerciante (su negocio)
      GoRoute(
        path: '/negocio/producto',
        builder: (_, s) => ProductoFormScreen(producto: s.extra is MiProducto ? s.extra! as MiProducto : null),
      ),
      GoRoute(path: '/negocio/pedido/:id', builder: (_, s) => PedidoNegocioScreen(pedidoId: _id(s))),
      GoRoute(path: '/negocio/registros', builder: (_, _) => const RegistrosScreen()),
      GoRoute(path: '/negocio/calificaciones', builder: (_, _) => const CalificacionesScreen()),
      GoRoute(path: '/negocio/perfil', builder: (_, _) => const PerfilNegocioScreen()),
      GoRoute(path: '/negocio/horario', builder: (_, _) => const HorarioScreen()),
    ],
  );
});
