import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';
import 'calificar_sheet.dart';
import 'widgets/piezas_pedido.dart';

/// Detalle de un pedido para el cliente: avance, PIN de entrega, productos,
/// cancelar (mientras está pendiente) y calificar (cuando ya llegó).
class PedidoScreen extends ConsumerStatefulWidget {
  const PedidoScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  ConsumerState<PedidoScreen> createState() => _PedidoScreenState();
}

class _PedidoScreenState extends ConsumerState<PedidoScreen> {
  Timer? _reloj;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    // Mientras el pedido está en curso, se actualiza solo cada 20 segundos.
    _reloj = Timer.periodic(const Duration(seconds: 20), (_) {
      final estado = ref.read(pedidoProvider(widget.pedidoId)).value?.estado;
      if (estado != null && !estado.terminado) ref.invalidate(pedidoProvider(widget.pedidoId));
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cancelar el pedido?'),
        content: const Text('Puedes cancelarlo mientras el negocio todavía no lo aceptó.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cancelando = true);
    try {
      await ref.read(pedidosRepositoryProvider).cancelar(widget.pedidoId);
      ref.invalidate(pedidoProvider(widget.pedidoId));
      ref.invalidate(misPedidosProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.errorDe('estado') ?? e.mensaje)));
      ref.invalidate(pedidoProvider(widget.pedidoId));
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  Future<void> _calificar(Future<bool> calificacion) async {
    if (await calificacion) {
      ref.invalidate(pedidoProvider(widget.pedidoId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias por tu calificación!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoProvider(widget.pedidoId));
    final titulo = 'Pedido #${widget.pedidoId}';

    return pedido.when(
      skipLoadingOnRefresh: true,
      loading: () => Pantalla(titulo: titulo, child: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Pantalla(
        titulo: titulo,
        child: VistaError(error: e, alReintentar: () => ref.invalidate(pedidoProvider(widget.pedidoId))),
      ),
      data: (p) {
        final textos = Theme.of(context).textTheme;
        final c = Theme.of(context).colorScheme;
        final puedeCancelar = p.acciones.contains(EstadoPedido.cancelado);

        return Pantalla(
          titulo: titulo,
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(pedidoProvider(widget.pedidoId).future),
            child: ListView(
              padding: const EdgeInsets.all(AppEspacios.m),
              children: [
                Tarjeta3D(
                  inclinacionMax: 3,
                  padding: const EdgeInsets.all(AppEspacios.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ImagenRed(p.negocioLogo, ancho: 48, alto: 48, radio: 12, icono: Icons.storefront),
                          const SizedBox(width: AppEspacios.m - 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => context.push('/tienda/${p.negocioId}'),
                                  child: Text(p.negocioNombre, style: textos.titleMedium),
                                ),
                                Text(Formato.fechaHora(p.creado), style: textos.bodySmall),
                                const SizedBox(height: AppEspacios.xs),
                                // Debajo del nombre: al lado no cabe en celulares angostos.
                                EtiquetaEstado(p.estado),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!p.estado.terminado && p.codigoEntrega != null) ...[
                        const SizedBox(height: AppEspacios.m),
                        Container(
                          padding: const EdgeInsets.all(AppEspacios.m - 4),
                          decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              Text('Tu PIN de entrega', style: textos.labelLarge),
                              Text(
                                p.codigoEntrega!,
                                key: const Key('pin-entrega'),
                                style: textos.displaySmall?.copyWith(letterSpacing: 10, fontWeight: FontWeight.w800),
                              ),
                              Text('Dáselo a quien te entregue el pedido, solo al recibirlo.',
                                  textAlign: TextAlign.center, style: textos.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppEspacios.m),
                Card(child: Padding(padding: const EdgeInsets.all(AppEspacios.m), child: LineaAvance(pedido: p))),
                if (p.estado == EstadoPedido.entregado) ...[
                  const SizedBox(height: AppEspacios.m),
                  Card(
                    color: c.primaryContainer.withValues(alpha: 0.35),
                    child: ListTile(
                      key: const Key('calificar-negocio'),
                      leading: const Icon(Icons.star_rounded, color: Color(0xFFF5A524)),
                      title: Text(p.resenaNegocio == null ? '¿Qué tal ${p.negocioNombre}?' : 'Tu calificación del negocio'),
                      subtitle: p.resenaNegocio == null
                          ? const Text('Toca para calificar')
                          : EstrellasFijas(p.resenaNegocio!.estrellas),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _calificar(mostrarCalificar(
                        context,
                        titulo: 'Califica a ${p.negocioNombre}',
                        negocioId: p.negocioId,
                        estrellas: p.resenaNegocio?.estrellas,
                        comentario: p.resenaNegocio?.comentario,
                      )),
                    ),
                  ),
                ],
                const SizedBox(height: AppEspacios.m),
                const TituloSeccion('Productos', Icons.shopping_bag_outlined),
                DetalleMontos(
                  pedido: p,
                  alCalificarProducto: p.estado == EstadoPedido.entregado
                      ? (item) => _calificar(mostrarCalificar(
                            context,
                            titulo: 'Califica «${item.nombre}»',
                            productoId: item.productoId,
                            estrellas: p.resenaDe(item.productoId)?.estrellas,
                            comentario: p.resenaDe(item.productoId)?.comentario,
                          ))
                      : null,
                ),
                const SizedBox(height: AppEspacios.m),
                const TituloSeccion('Entrega', Icons.place_outlined),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: Text(p.direccionEntrega),
                    subtitle: p.referenciaEntrega == null ? null : Text(p.referenciaEntrega!),
                  ),
                ),
                if (p.notas != null) ...[
                  const SizedBox(height: AppEspacios.s),
                  Card(child: ListTile(leading: const Icon(Icons.chat_bubble_outline), title: Text(p.notas!))),
                ],
                if (puedeCancelar) ...[
                  const SizedBox(height: AppEspacios.l),
                  OutlinedButton.icon(
                    key: const Key('cancelar-pedido'),
                    style: OutlinedButton.styleFrom(foregroundColor: c.error),
                    onPressed: _cancelando ? null : _cancelar,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar pedido'),
                  ),
                ],
                const SizedBox(height: AppEspacios.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}
