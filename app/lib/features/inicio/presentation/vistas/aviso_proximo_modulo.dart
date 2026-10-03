import 'package:flutter/material.dart';

/// Mensaje centrado con ícono. Se usa mientras una vista no tiene su
/// contenido real (y para estados como "solicitud en revisión").
class AvisoProximoModulo extends StatelessWidget {
  const AvisoProximoModulo({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    this.esProximoModulo = true,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final bool esProximoModulo;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 72, color: colores.primary),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: colores.onSurfaceVariant)),
            if (esProximoModulo) ...[
              const SizedBox(height: 16),
              Chip(label: const Text('Próximo módulo'), avatar: Icon(Icons.construction, size: 18, color: colores.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
