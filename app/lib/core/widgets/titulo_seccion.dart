import 'package:flutter/material.dart';

import '../theme/app_espacios.dart';

/// Título de sección de un formulario: ícono en un cuadradito de color + texto.
/// (Mismo diseño que las secciones del registro.)
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, this.icono, {super.key, this.opcional = false});

  final String texto;
  final IconData icono;

  /// Agrega "(opcional)" en gris al lado del título.
  final bool opcional;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacios.m - 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 18, color: c.onSecondaryContainer),
          ),
          const SizedBox(width: AppEspacios.s + 2),
          Flexible(child: Text(texto, style: textos.titleMedium)),
          if (opcional) ...[
            const SizedBox(width: AppEspacios.xs + 2),
            Text('(opcional)', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
