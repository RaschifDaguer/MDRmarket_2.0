import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../pedidos/domain/pedido.dart';
import '../../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../../data/mi_negocio_repository.dart';
import '../../domain/negocio.dart';
import '../pedido_negocio_screen.dart';
import '../widgets/cuenta_regresiva.dart';

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
                  ? ListView(
                      children: [
                        EstadoVacio(
                          icono: Icons.receipt_long_outlined,
                          titulo: switch (_grupo) {
                            'nuevos' => 'No hay pedidos nuevos',
                            'en_curso' => 'No hay pedidos en curso',
                            _ => 'Todavía no hay pedidos terminados',
                          },
                          texto: _grupo == 'nuevos' ? 'Cuando llegue uno, aparecerá aquí.' : null,
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppEspacios.m, 0, AppEspacios.m, AppEspacios.l),
                      children: [
                        for (final p in pagina.items)
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: _TarjetaPedidoNegocio(pedido: p, negocioId: widget.negocio.id),
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

/// Un pedido en la lista: quién, qué productos, cómo paga y cuánto. Nuevo:
/// la cuenta regresiva y Aceptar o Rechazar ahí mismo. Listo o en camino:
/// "Buscando repartidor…" o "Lo lleva…".
class _TarjetaPedidoNegocio extends ConsumerStatefulWidget {
  const _TarjetaPedidoNegocio({required this.pedido, required this.negocioId});

  final Pedido pedido;
  final int negocioId;

  @override
  ConsumerState<_TarjetaPedidoNegocio> createState() => _TarjetaPedidoNegocioState();
}

class _TarjetaPedidoNegocioState extends ConsumerState<_TarjetaPedidoNegocio> {
  bool _cambiando = false;

  Future<void> _responder(EstadoPedido estado) async {
    String? motivo;
    if (estado == EstadoPedido.rechazado) {
      motivo = await showDialog<String>(
        context: context,
        builder: (_) => const DialogoMotivo(titulo: '¿Por qué lo rechazas?'),
      );
      if (motivo == null) return;
    }
    setState(() => _cambiando = true);
    try {
      await ref
          .read(miNegocioRepositoryProvider)
          .cambiarEstado(widget.negocioId, widget.pedido.id, estado, motivo: motivo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              estado == EstadoPedido.confirmado ? 'Pedido aceptado: ya puedes alistarlo' : 'Pedido rechazado',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.errorDe('estado') ?? e.mensaje)));
      }
    } finally {
      ref.invalidate(pedidosNegocioProvider);
      ref.invalidate(resumenNegocioProvider(widget.negocioId));
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final nuevo = pedido.estado == EstadoPedido.pendiente;
    final puedeAceptar = pedido.acciones.contains(EstadoPedido.confirmado);
    final pago = [
      pedido.metodoPago == 'qr' ? 'QR' : 'Efectivo',
      if (pedido.distanciaKm != null) '${pedido.distanciaKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
    ].join(' · ');
    const maxLineas = 3;

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
                      child: Text(
                        '#${pedido.id} · ${pedido.clienteNombre ?? 'Cliente'}',
                        style: textos.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    EtiquetaEstado(pedido.estado),
                  ],
                ),
                Text(Formato.hace(pedido.creado), style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                const SizedBox(height: AppEspacios.xs),
                if (pedido.items.isEmpty)
                  Text('${pedido.unidades} producto${pedido.unidades == 1 ? '' : 's'}', style: textos.bodyMedium)
                else ...[
                  for (final i in pedido.items.take(maxLineas))
                    Text(
                      '${i.cantidad}× ${i.nombre}',
                      style: textos.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (pedido.items.length > maxLineas)
                    Text('y ${pedido.items.length - maxLineas} más', style: textos.bodySmall),
                ],
                const SizedBox(height: AppEspacios.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(pago, style: textos.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(Formato.bs(pedido.total), style: textos.titleSmall),
                  ],
                ),
                if (nuevo && pedido.aceptarAntes != null) ...[
                  const SizedBox(height: AppEspacios.s),
                  CuentaRegresiva(hasta: pedido.aceptarAntes!, compacta: true),
                ],
                if (nuevo && puedeAceptar) ...[
                  const SizedBox(height: AppEspacios.s),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: Key('rechazar-${pedido.id}'),
                          style: OutlinedButton.styleFrom(foregroundColor: c.error, minimumSize: const Size(0, 44)),
                          onPressed: _cambiando ? null : () => _responder(EstadoPedido.rechazado),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: AppEspacios.s),
                      Expanded(
                        child: FilledButton(
                          key: Key('aceptar-${pedido.id}'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: _cambiando ? null : () => _responder(EstadoPedido.confirmado),
                          child: const Text('Aceptar'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (pedido.estado == EstadoPedido.preparando && pedido.items.isNotEmpty) ...[
                  const SizedBox(height: AppEspacios.s),
                  Text(
                    'Alistando · ${pedido.alistados} de ${pedido.items.length} productos',
                    style: textos.bodySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w600),
                  ),
                ],
                if (!pedido.estado.terminado && (pedido.tieneRepartidor || pedido.estado == EstadoPedido.listo)) ...[
                  const Divider(height: AppEspacios.l),
                  EstadoReparto(pedido: pedido, compacto: true),
                ],
                if (pedido.esperandoPagoQr)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_2, size: 16, color: c.tertiary),
                        const SizedBox(width: 4),
                        Text('Esperando el pago con QR', style: textos.bodySmall?.copyWith(color: c.tertiary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
