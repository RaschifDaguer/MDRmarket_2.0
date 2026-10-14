import 'package:flutter/material.dart';

/// Foto que viene de internet (producto, negocio). Mientras carga o si falla,
/// muestra un recuadro con un ícono en vez de un error.
class ImagenRed extends StatelessWidget {
  const ImagenRed(
    this.url, {
    super.key,
    this.ancho,
    this.alto,
    this.radio = 16,
    this.icono = Icons.image_outlined,
  });

  final String? url;
  final double? ancho;
  final double? alto;
  final double radio;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final respaldo = ColoredBox(
      color: c.secondaryContainer,
      child: Center(child: Icon(icono, color: c.onSecondaryContainer.withValues(alpha: 0.6))),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: url == null || url!.isEmpty
            ? respaldo
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => respaldo,
                loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : respaldo,
              ),
      ),
    );
  }
}
