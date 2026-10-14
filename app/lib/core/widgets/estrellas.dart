import 'package:flutter/material.dart';

/// "⭐ 4.5 (17)" — promedio de reseñas. Sin reseñas muestra "Nuevo".
class Calificacion extends StatelessWidget {
  const Calificacion({super.key, required this.promedio, required this.total, this.compacto = false});

  final double? promedio;
  final int total;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final estilo = (compacto ? Theme.of(context).textTheme.bodySmall : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: c.onSurfaceVariant);
    if (promedio == null || total == 0) {
      return Text('Nuevo', style: estilo);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: compacto ? 15 : 18, color: const Color(0xFFF5A524)),
        const SizedBox(width: 2),
        Text('${promedio!.toStringAsFixed(1)} ($total)', style: estilo),
      ],
    );
  }
}

/// Cinco estrellas fijas (para mostrar una reseña).
class EstrellasFijas extends StatelessWidget {
  const EstrellasFijas(this.valor, {super.key, this.tamano = 16});

  final int valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final apagada = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(Icons.star_rounded, size: tamano, color: i <= valor ? const Color(0xFFF5A524) : apagada),
      ],
    );
  }
}

/// Cinco estrellas para tocar y elegir de 1 a 5.
class SelectorEstrellas extends StatelessWidget {
  const SelectorEstrellas({super.key, required this.valor, required this.alCambiar, this.tamano = 36});

  final int valor;
  final ValueChanged<int> alCambiar;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final apagada = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            key: Key('estrella-$i'),
            tooltip: '$i estrella${i == 1 ? '' : 's'}',
            onPressed: () => alCambiar(i),
            icon: Icon(Icons.star_rounded, size: tamano, color: i <= valor ? const Color(0xFFF5A524) : apagada),
          ),
      ],
    );
  }
}
