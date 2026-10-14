import 'package:flutter/material.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/pedido.dart';

/// Etiqueta de color con el estado del pedido.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});

  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (fondo, texto) = switch (estado) {
      EstadoPedido.pendiente => (const Color(0xFFFFF1D6), const Color(0xFF8A5300)),
      EstadoPedido.entregado => (c.primaryContainer, c.onPrimaryContainer),
      EstadoPedido.cancelado || EstadoPedido.rechazado => (c.errorContainer, c.onErrorContainer),
      _ => (c.secondaryContainer, c.onSecondaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppEspacios.s + 2, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 14, color: texto),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              estado.texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: texto, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea de avance: pendiente → aceptado → … → entregado, con la hora de cada paso.
class LineaAvance extends StatelessWidget {
  const LineaAvance({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    if (pedido.estado.fallido) {
      return AvisoError(
        '${pedido.estado == EstadoPedido.rechazado ? 'El negocio rechazó el pedido' : 'Pedido cancelado'}'
        '${pedido.motivoCancelacion != null ? ': ${pedido.motivoCancelacion}' : '.'}',
      );
    }
    final actual = EstadoPedido.camino.indexOf(pedido.estado);
    return Column(
      children: [
        for (var i = 0; i < EstadoPedido.camino.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    i <= actual ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 22,
                    color: i <= actual ? c.primary : c.outlineVariant,
                  ),
                  if (i < EstadoPedido.camino.length - 1)
                    Container(width: 2, height: 22, color: i < actual ? c.primary : c.outlineVariant),
                ],
              ),
              const SizedBox(width: AppEspacios.m - 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    EstadoPedido.camino[i].texto,
                    style: textos.bodyMedium?.copyWith(
                      fontWeight: i == actual ? FontWeight.w700 : FontWeight.w400,
                      color: i <= actual ? c.onSurface : c.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Text(Formato.fechaHora(pedido.fechaDe(EstadoPedido.camino[i])), style: textos.bodySmall),
            ],
          ),
      ],
    );
  }
}

/// Productos del pedido con sus notas y los montos.
class DetalleMontos extends StatelessWidget {
  const DetalleMontos({super.key, required this.pedido, this.alCalificarProducto});

  final Pedido pedido;

  /// Si llega, muestra "Calificar" al lado de cada producto (pedido entregado).
  final void Function(ItemPedido item)? alCalificarProducto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in pedido.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppEspacios.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ImagenRed(item.imagenUrl, ancho: 44, alto: 44, radio: 10),
                    const SizedBox(width: AppEspacios.m - 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.cantidad} × ${item.nombre}', style: textos.bodyMedium),
                          if (item.notas != null)
                            Text('Nota: ${item.notas}', style: textos.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                          if (alCalificarProducto != null)
                            _CalificarItem(
                              estrellas: pedido.resenaDe(item.productoId)?.estrellas,
                              alTocar: () => alCalificarProducto!(item),
                            ),
                        ],
                      ),
                    ),
                    Text(Formato.bs(item.subtotal), style: textos.bodyMedium),
                  ],
                ),
              ),
            const Divider(height: AppEspacios.l),
            _Monto('Subtotal', pedido.subtotal),
            _Monto('Envío', pedido.costoEnvio),
            if (pedido.tarifaServicio > 0) _Monto('Servicio', pedido.tarifaServicio),
            const SizedBox(height: AppEspacios.xs),
            Row(
              children: [
                Text('Total', style: textos.titleMedium),
                const Spacer(),
                Text(Formato.bs(pedido.total), style: textos.titleMedium),
              ],
            ),
            const SizedBox(height: AppEspacios.xs),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 18, color: c.onSurfaceVariant),
                const SizedBox(width: AppEspacios.xs),
                Text(pedido.metodoPagoTexto, style: textos.bodySmall),
                const Spacer(),
                if (pedido.estadoPago == 'pagado') Text('Pagado', style: textos.bodySmall?.copyWith(color: c.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Monto extends StatelessWidget {
  const _Monto(this.texto, this.valor);

  final String texto;
  final double valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Text(texto), const Spacer(), Text(Formato.bs(valor))]),
      );
}

class _CalificarItem extends StatelessWidget {
  const _CalificarItem({required this.estrellas, required this.alTocar});

  final int? estrellas;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: estrellas == null
            ? Text('Calificar producto', style: TextStyle(color: Theme.of(context).colorScheme.primary))
            : EstrellasFijas(estrellas!, tamano: 16),
      ),
    );
  }
}
