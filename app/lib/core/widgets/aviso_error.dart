import 'package:flutter/material.dart';

import '../theme/app_espacios.dart';

/// Caja roja suave con un ícono para mostrar un mensaje de error general
/// (por ejemplo, el que devuelve la API).
class AvisoError extends StatelessWidget {
  const AvisoError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppEspacios.m - 2),
      decoration: BoxDecoration(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(AppRadios.campo),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: c.onErrorContainer),
          const SizedBox(width: AppEspacios.m - 4),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: c.onErrorContainer, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
