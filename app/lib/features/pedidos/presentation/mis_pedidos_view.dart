import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';
import 'widgets/piezas_pedido.dart';

/// Pestaña "Pedidos" del cliente: sus pedidos, los en curso primero.
class MisPedidosView extends ConsumerWidget {
  const MisPedidosView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(misPedidosProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(misPedidosProvider.future),
      child: pedidos.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [VistaError(error: e, alReintentar: () => ref.invalidate(misPedidosProvider))]),
        data: (pagina) {
          if (pagina.items.isEmpty) {
            return ListView(children: const [
              EstadoVacio(
                icono: Icons.receipt_long_outlined,
                titulo: 'Todavía no hiciste pedidos',
                texto: 'Cuando pidas algo, aquí verás cómo va.',
              ),
            ]);
          }
          final enCurso = pagina.items.where((p) => !p.estado.terminado).toList();
          final anteriores = pagina.items.where((p) => p.estado.terminado).toList();
          return ListView(
            padding: const EdgeInsets.all(AppEspacios.m),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (enCurso.isNotEmpty) ...[
                        const TituloSeccion('En curso', Icons.delivery_dining_outlined),
                        for (final p in enCurso) _TarjetaPedido(p),
                        const SizedBox(height: AppEspacios.m),
                      ],
                      if (anteriores.isNotEmpty) ...[
                        const TituloSeccion('Anteriores', Icons.history),
                        for (final p in anteriores) _TarjetaPedido(p),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido(this.pedido);

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacios.s),
      child: Card(
        child: InkWell(
          key: Key('pedido-${pedido.id}'),
          onTap: () => context.push('/pedido/${pedido.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppEspacios.m - 4),
            child: Row(
              children: [
                ImagenRed(pedido.negocioLogo, ancho: 52, alto: 52, radio: 12, icono: Icons.storefront),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pedido.negocioNombre, style: textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '#${pedido.id} · ${pedido.unidades} producto${pedido.unidades == 1 ? '' : 's'} · ${Formato.fechaHora(pedido.creado)}',
                        style: textos.bodySmall,
                      ),
                      const SizedBox(height: AppEspacios.xs),
                      EtiquetaEstado(pedido.estado),
                    ],
                  ),
                ),
                Text(Formato.bs(pedido.total), style: textos.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
