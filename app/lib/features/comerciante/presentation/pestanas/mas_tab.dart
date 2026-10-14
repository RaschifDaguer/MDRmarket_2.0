import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/negocio.dart';

/// "Más": compras y gastos, calificaciones, perfil y horario del negocio.
class MasTab extends StatelessWidget {
  const MasTab({super.key, required this.negocio});

  final Negocio negocio;

  @override
  Widget build(BuildContext context) {
    final opciones = [
      (Icons.receipt_long_outlined, 'Compras y gastos', 'Anota lo que compras para vender y tus gastos', '/negocio/registros'),
      (
        Icons.star_outline_rounded,
        'Calificaciones',
        negocio.totalResenas == 0
            ? 'Todavía no tienes reseñas'
            : '⭐ ${negocio.ratingPromedio?.toStringAsFixed(1)} · ${negocio.totalResenas} reseñas',
        '/negocio/calificaciones',
      ),
      (Icons.storefront_outlined, 'Perfil del negocio', 'Nombre, foto, ubicación, pedido mínimo…', '/negocio/perfil'),
      (Icons.schedule, 'Horario de atención', '${negocio.horarios.length} tramos cargados', '/negocio/horario'),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppEspacios.m),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                for (final (icono, titulo, subtitulo, ruta) in opciones)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppEspacios.s),
                    child: ListTile(
                      key: Key('mas-$ruta'),
                      leading: Icon(icono, color: Theme.of(context).colorScheme.primary),
                      title: Text(titulo),
                      subtitle: Text(subtitulo),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(ruta),
                    ),
                  ),
                const SizedBox(height: AppEspacios.l),
                const EstadoVacio(
                  icono: Icons.delivery_dining_outlined,
                  titulo: 'Entregas',
                  texto: 'Por ahora entregas con tu propio delivery: al llegar, pide al cliente su PIN de 4 '
                      'números y marca el pedido como entregado.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
