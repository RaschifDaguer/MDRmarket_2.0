import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';

/// Pantalla de arranque mientras se revisa la sesión guardada.
/// Si el servidor no responde, muestra el error y un botón para reintentar.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: CabeceraFlotante(
        redondeada: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppEspacios.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoLatiendo(),
              const SizedBox(height: AppEspacios.l),
              Aparecer(
                orden: 3,
                child: Text(
                  'MDR Market',
                  style: textos.headlineLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: AppEspacios.xl),
              if (auth case AsyncError(:final error))
                Aparecer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Tarjeta3D(
                      inclinacionMax: 6,
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 40, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: AppEspacios.m - 4),
                          Text('$error', textAlign: TextAlign.center, style: textos.bodyLarge),
                          const SizedBox(height: AppEspacios.l - 4),
                          BotonPrincipal(
                            texto: 'Reintentar',
                            icono: Icons.refresh,
                            onPressed: () => ref.invalidate(authControllerProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo que entra con un pequeño rebote y un anillo que "late" detrás.
class _LogoLatiendo extends StatelessWidget {
  const _LogoLatiendo();

  static const _tamano = 96.0;

  @override
  Widget build(BuildContext context) {
    const logo = LogoMarca(tamano: _tamano, sobreColor: true);
    if (!AppMovimiento.activo(context)) return logo;

    return SizedBox.square(
      dimension: _tamano * 1.7,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anillo que crece y se desvanece, una y otra vez.
          Container(
            width: _tamano,
            height: _tamano,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_tamano * 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
          )
              .animate(onPlay: (control) => control.repeat())
              .scaleXY(begin: 1, end: 1.6, duration: 1600.ms, curve: Curves.easeOut)
              .fadeOut(duration: 1600.ms, curve: Curves.easeIn),
          logo
              .animate()
              .scaleXY(begin: 0.6, end: 1, duration: 600.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}
