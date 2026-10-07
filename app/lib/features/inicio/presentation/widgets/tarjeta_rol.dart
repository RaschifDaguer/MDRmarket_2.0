import 'package:flutter/material.dart';

import '../../../../core/theme/app_colores.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';

/// Color de la tarjeta según el rol o el estado que muestra.
enum TonoRol { cliente, comerciante, repartidor, espera, alerta }

/// Tarjeta principal de cada vista: ícono grande en un cuadrado de color,
/// título y texto. Se inclina en 3D con el mouse o el dedo.
class TarjetaRol extends StatelessWidget {
  const TarjetaRol({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    this.tono = TonoRol.cliente,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final TonoRol tono;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    // Fondo del ícono y color del ícono.
    final (List<Color> fondo, Color colorIcono) = switch (tono) {
      TonoRol.cliente => (const [AppColores.intermedio, AppColores.primario], AppColores.blanco),
      TonoRol.comerciante => (const [AppColores.primario, AppColores.primarioOscuro], AppColores.blanco),
      TonoRol.repartidor => (const [AppColores.claro, AppColores.intermedio], AppColores.blanco),
      TonoRol.espera => ([c.secondaryContainer, c.secondaryContainer], c.onSecondaryContainer),
      TonoRol.alerta => ([c.errorContainer, c.errorContainer], c.onErrorContainer),
    };

    return Tarjeta3D(
      inclinacionMax: 6,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: fondo,
              ),
            ),
            child: Icon(icono, size: 32, color: colorIcono),
          ),
          const SizedBox(width: AppEspacios.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleLarge),
                const SizedBox(height: AppEspacios.xs),
                Text(texto, style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
