import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colores.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido.dart';

/// Etiquetas que acepta la API para el repartidor.
const etiquetasRepartidor = ['Puntual', 'Amable', 'Cuidó el paquete'];

/// "¿Qué tal Diego?": estrellas y etiquetas para el repartidor que entregó el
/// pedido. Si ya lo calificó, muestra lo que puso y se puede cambiar.
class CalificarRepartidor extends ConsumerStatefulWidget {
  const CalificarRepartidor({super.key, required this.pedido, required this.alGuardar});

  final Pedido pedido;
  final VoidCallback alGuardar;

  @override
  ConsumerState<CalificarRepartidor> createState() => _CalificarRepartidorState();
}

class _CalificarRepartidorState extends ConsumerState<CalificarRepartidor> {
  late int _estrellas = widget.pedido.resenaRepartidor?.estrellas ?? 0;
  late final Set<String> _etiquetas = {...?widget.pedido.resenaRepartidor?.etiquetas};
  bool _guardando = false;

  static const _textos = ['', 'Muy mal', 'Mal', 'Regular', 'Bien', '¡Excelente!'];

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(pedidosRepositoryProvider)
          .calificarRepartidor(
            repartidorId: widget.pedido.repartidorId!,
            estrellas: _estrellas,
            etiquetas: etiquetasRepartidor.where(_etiquetas.contains).toList(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias por calificar a tu repartidor!')));
      }
      widget.alGuardar();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.errores.values.firstOrNull?.firstOrNull ?? e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final nombre = (widget.pedido.repartidorNombre ?? 'tu repartidor').split(' ').first;
    final yaCalificado = widget.pedido.resenaRepartidor != null;

    return Card(
      key: const Key('calificar-repartidor'),
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: c.secondaryContainer,
                  child: Icon(Icons.delivery_dining, color: c.primary),
                ),
                const SizedBox(width: AppEspacios.s + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Qué tal $nombre?', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Tu repartidor', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspacios.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: Key('estrella-repartidor-$i'),
                    tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
                    iconSize: 36,
                    onPressed: () => setState(() => _estrellas = i),
                    icon: Icon(
                      i <= _estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i <= _estrellas ? AppColores.ambar : c.outline,
                    ),
                  ),
              ],
            ),
            if (_estrellas > 0) Text(_textos[_estrellas], textAlign: TextAlign.center, style: textos.bodyMedium),
            const SizedBox(height: AppEspacios.s),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppEspacios.s,
              children: [
                for (final etiqueta in etiquetasRepartidor)
                  FilterChip(
                    key: Key('etiqueta-$etiqueta'),
                    label: Text(etiqueta),
                    selected: _etiquetas.contains(etiqueta),
                    onSelected: (si) => setState(() => si ? _etiquetas.add(etiqueta) : _etiquetas.remove(etiqueta)),
                  ),
              ],
            ),
            const SizedBox(height: AppEspacios.m),
            BotonPrincipal(
              key: const Key('enviar-calificacion-repartidor'),
              texto: yaCalificado ? 'Guardar cambios' : 'Enviar calificación',
              icono: Icons.star_rounded,
              cargando: _guardando,
              onPressed: _estrellas == 0 ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
