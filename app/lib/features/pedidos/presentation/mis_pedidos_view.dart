import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';
import 'volver_a_pedir.dart';
import 'widgets/piezas_pedido.dart';

/// Pestaña "Pedidos" del cliente: sus pedidos, los en curso primero (con un
/// avance en pasos) y los anteriores con "Volver a pedir".
class MisPedidosView extends ConsumerWidget {
  const MisPedidosView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(misPedidosProvider);

    // Solo, cada pocos segundos: el estado de cada pedido (aceptado, en camino…).
    return ActualizacionAutomatica(
      alActualizar: () => ref.invalidate(misPedidosProvider),
      cada: const Duration(seconds: 10),
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(misPedidosProvider.future),
        child: pedidos.when(
          skipLoadingOnRefresh: true,
          skipError: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [VistaError(error: e, alReintentar: () => ref.invalidate(misPedidosProvider))],
          ),
          data: (pagina) {
            if (pagina.items.isEmpty) {
              return ListView(
                children: const [
                  EstadoVacio(
                    icono: Icons.receipt_long_outlined,
                    titulo: 'Todavía no hiciste pedidos',
                    texto: 'Cuando pidas algo, aquí verás cómo va.',
                  ),
                ],
              );
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
                        Text(
                          'Mis pedidos',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppEspacios.m),
                        if (enCurso.isNotEmpty) ...[
                          const TituloSeccion('En curso', Icons.delivery_dining_outlined),
                          for (final (i, p) in enCurso.indexed) Aparecer(orden: i, child: _TarjetaPedido(p)),
                          const SizedBox(height: AppEspacios.m),
                        ],
                        if (anteriores.isNotEmpty) ...[
                          const TituloSeccion('Anteriores', Icons.history),
                          for (final (i, p) in anteriores.indexed)
                            Aparecer(orden: (enCurso.length + i).clamp(0, 8), child: _TarjetaPedido(p)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaPedido extends ConsumerWidget {
  const _TarjetaPedido(this.pedido);

  final Pedido pedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
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
                      Text(
                        pedido.negocioNombre,
                        style: textos.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '#${pedido.id} · ${pedido.unidades} producto${pedido.unidades == 1 ? '' : 's'} · ${Formato.fechaHora(pedido.creado)}',
                        style: textos.bodySmall,
                      ),
                      const SizedBox(height: AppEspacios.xs),
                      Wrap(
                        spacing: AppEspacios.s,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          EtiquetaEstado(pedido.estado),
                          if (pedido.estadoPago == 'reembolsado')
                            Text(
                              'Reembolsado',
                              style: textos.bodySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                      if (!pedido.estado.terminado) ...[const SizedBox(height: AppEspacios.s), _Pasos(pedido.estado)],
                      if (pedido.estado == EstadoPedido.entregado)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: Key('volver-a-pedir-${pedido.id}'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                            onPressed: () => volverAPedir(context, ref, pedido),
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('Volver a pedir'),
                          ),
                        ),
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

/// Avance en 4 pasos: Aceptado · Recogido · En camino · Entregado.
class _Pasos extends StatelessWidget {
  const _Pasos(this.estado);

  final EstadoPedido estado;

  static const _nombres = ['Aceptado', 'Recogido', 'En camino', 'Entregado'];

  /// Cuántos pasos ya pasó.
  int get _hechos => switch (estado) {
    EstadoPedido.pendiente => 0,
    EstadoPedido.confirmado || EstadoPedido.preparando || EstadoPedido.listo => 1,
    EstadoPedido.enCamino => 3,
    EstadoPedido.entregado => 4,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Column(
      key: const Key('pasos-pedido'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < _hechos ? c.primary : c.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (i, nombre) in _nombres.indexed)
              Expanded(
                child: Text(
                  nombre,
                  style: textos.labelSmall?.copyWith(
                    color: i < _hechos ? c.primary : c.onSurfaceVariant,
                    fontWeight: i < _hechos ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
