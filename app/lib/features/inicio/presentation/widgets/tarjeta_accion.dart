import 'package:flutter/material.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';

/// Tarjeta que invita a hacer algo: ícono, título, texto y un botón.
/// Ej. "¿Tienes un negocio? Regístralo".
class TarjetaAccion extends StatelessWidget {
  const TarjetaAccion({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.alPresionar,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Tarjeta3D(
      inclinacionMax: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppEspacios.m - 4),
                decoration: BoxDecoration(
                  color: c.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, color: c.onSecondaryContainer),
              ),
              const SizedBox(width: AppEspacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: textos.titleMedium),
                    const SizedBox(height: 2),
                    Text(texto, style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspacios.m),
          BotonPrincipal(texto: boton, icono: Icons.arrow_forward, onPressed: alPresionar),
        ],
      ),
    );
  }
}
