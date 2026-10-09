import 'package:flutter/material.dart';

import '../theme/app_espacios.dart';
import '../theme/app_movimiento.dart';
import 'reaccion_toque.dart';

/// Botón principal de cada pantalla: grande, con resplandor, que se hunde al
/// tocarlo y muestra un círculo de carga mientras [cargando] es `true`.
///
/// Por dentro es un [FilledButton] con un [Text]: las pruebas lo buscan así.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.icono,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  /// Ícono opcional a la izquierda del texto.
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final habilitado = onPressed != null && !cargando;

    return ReaccionToque(
      habilitado: habilitado,
      child: AnimatedContainer(
        duration: AppMovimiento.normal,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadios.boton),
          boxShadow: habilitado ? AppSombras.brillo(c.primary) : const [],
        ),
        child: FilledButton(
          onPressed: cargando ? null : onPressed,
          // Mientras carga, el botón conserva su color en vez de verse gris.
          style: cargando
              ? FilledButton.styleFrom(
                  disabledBackgroundColor: c.primary,
                  disabledForegroundColor: c.onPrimary,
                )
              : null,
          child: AnimatedSwitcher(
            duration: AppMovimiento.activo(context) ? AppMovimiento.rapido : Duration.zero,
            child: cargando
                ? SizedBox.square(
                    key: const ValueKey('cargando'),
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onPrimary),
                  )
                : Row(
                    key: const ValueKey('texto'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icono != null) ...[
                        Icon(icono, size: 20),
                        const SizedBox(width: AppEspacios.s),
                      ],
                      // Flexible: en pantallas angostas o con letra grande no desborda.
                      Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
