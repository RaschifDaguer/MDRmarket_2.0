import 'package:flutter/material.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/resena.dart';

/// Una reseña: autor, estrellas, comentario y la respuesta del negocio.
class TarjetaResena extends StatelessWidget {
  const TarjetaResena({super.key, required this.resena, this.accion});

  final Resena resena;

  /// Botón opcional (ej. "Responder" en la vista comerciante).
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: c.secondaryContainer,
                  child: Text(resena.autor.characters.first.toUpperCase(),
                      style: TextStyle(color: c.onSecondaryContainer, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: AppEspacios.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resena.autor, style: textos.titleSmall),
                      Text(Formato.fecha(resena.fecha), style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
                EstrellasFijas(resena.estrellas),
              ],
            ),
            if (resena.productoNombre != null) ...[
              const SizedBox(height: AppEspacios.s),
              Text('Sobre: ${resena.productoNombre}', style: textos.bodySmall?.copyWith(color: c.primary)),
            ],
            if (resena.comentario != null && resena.comentario!.isNotEmpty) ...[
              const SizedBox(height: AppEspacios.s),
              Text(resena.comentario!, style: textos.bodyMedium),
            ],
            if (resena.respuesta != null) ...[
              const SizedBox(height: AppEspacios.s),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppEspacios.m - 4),
                decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Respuesta del negocio', style: textos.labelMedium?.copyWith(color: c.primary)),
                    const SizedBox(height: 2),
                    Text(resena.respuesta!, style: textos.bodyMedium),
                  ],
                ),
              ),
            ],
            if (accion != null) Align(alignment: Alignment.centerRight, child: accion!),
          ],
        ),
      ),
    );
  }
}
