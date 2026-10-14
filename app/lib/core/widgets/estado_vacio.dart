import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_espacios.dart';

/// Mensaje centrado para listas vacías ("Todavía no tienes pedidos").
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.texto,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? texto;

  /// Botón opcional (ej. "Agregar producto").
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppEspacios.l - 4),
              decoration: BoxDecoration(color: c.secondaryContainer, shape: BoxShape.circle),
              child: Icon(icono, size: 40, color: c.onSecondaryContainer),
            ),
            const SizedBox(height: AppEspacios.m),
            Text(titulo, style: textos.titleMedium, textAlign: TextAlign.center),
            if (texto != null) ...[
              const SizedBox(height: AppEspacios.xs),
              Text(texto!, textAlign: TextAlign.center, style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            ],
            if (accion != null) ...[const SizedBox(height: AppEspacios.m), accion!],
          ],
        ),
      ),
    );
  }
}

/// Error al cargar algo, con botón para reintentar.
class VistaError extends StatelessWidget {
  const VistaError({super.key, required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.cloud_off_outlined,
      titulo: 'No se pudo cargar',
      texto: error is ApiException ? (error as ApiException).mensaje : '$error',
      accion: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: alReintentar,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    );
  }
}
