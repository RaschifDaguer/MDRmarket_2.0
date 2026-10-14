import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../pedidos/domain/pedido.dart';
import '../../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../../data/mi_negocio_repository.dart';
import '../../domain/negocio.dart';

/// Pedidos que llegan al negocio: nuevos, en curso y terminados.
class PedidosTab extends ConsumerStatefulWidget {
  const PedidosTab({super.key, required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends ConsumerState<PedidosTab> {
  String _grupo = 'nuevos';
  Timer? _reloj;

  ({int negocioId, String grupo}) get _filtro => (negocioId: widget.negocio.id, grupo: _grupo);

  @override
  void initState() {
    super.initState();
    // Revisa cada 20 segundos si llegaron pedidos nuevos.
    _reloj = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(pedidosNegocioProvider(_filtro));
      ref.invalidate(resumenNegocioProvider(widget.negocio.id));
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosNegocioProvider(_filtro));
    final resumen = ref.watch(resumenNegocioProvider(widget.negocio.id)).value;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m, AppEspacios.m, AppEspacios.s),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'nuevos',
                    label: Text('Nuevos${(resumen?.pedidosNuevos ?? 0) > 0 ? ' (${resumen!.pedidosNuevos})' : ''}'),
                  ),
                  ButtonSegment(
                    value: 'en_curso',
                    label: Text('En curso${(resumen?.pedidosEnCurso ?? 0) > 0 ? ' (${resumen!.pedidosEnCurso})' : ''}'),
                  ),
                  const ButtonSegment(value: 'terminados', label: Text('Terminados')),
                ],
                selected: {_grupo},
                onSelectionChanged: (s) => setState(() => _grupo = s.first),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(pedidosNegocioProvider(_filtro).future),
            child: pedidos.when(
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [VistaError(error: e, alReintentar: () => ref.invalidate(pedidosNegocioProvider(_filtro)))],
              ),
              data: (pagina) => pagina.items.isEmpty
                  ? ListView(children: [
                      EstadoVacio(
                        icono: Icons.receipt_long_outlined,
                        titulo: switch (_grupo) {
                          'nuevos' => 'No hay pedidos nuevos',
                          'en_curso' => 'No hay pedidos en curso',
                          _ => 'Todavía no hay pedidos terminados',
                        },
                        texto: _grupo == 'nuevos' ? 'Cuando llegue uno, aparecerá aquí.' : null,
                      ),
                    ])
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppEspacios.m, 0, AppEspacios.m, AppEspacios.l),
                      children: [
                        for (final p in pagina.items)
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: _TarjetaPedidoNegocio(pedido: p),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaPedidoNegocio extends StatelessWidget {
  const _TarjetaPedidoNegocio({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final nuevo = pedido.estado == EstadoPedido.pendiente;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacios.s),
      child: Card(
        color: nuevo ? c.primaryContainer.withValues(alpha: 0.4) : null,
        child: InkWell(
          key: Key('pedido-negocio-${pedido.id}'),
          onTap: () => context.push('/negocio/pedido/${pedido.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppEspacios.m - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Pedido #${pedido.id}  ', style: textos.titleSmall),
                          TextSpan(text: Formato.hace(pedido.creado), style: textos.bodySmall),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    EtiquetaEstado(pedido.estado),
                  ],
                ),
                const SizedBox(height: AppEspacios.xs),
                Text(
                  '${pedido.clienteNombre ?? 'Cliente'} · ${pedido.unidades} producto${pedido.unidades == 1 ? '' : 's'}',
                  style: textos.bodyMedium,
                ),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: c.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(pedido.direccionEntrega,
                          style: textos.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(Formato.bs(pedido.total), style: textos.titleSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
