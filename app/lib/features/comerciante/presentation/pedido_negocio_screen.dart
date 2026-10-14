import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/domain/pedido.dart';
import '../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../data/mi_negocio_repository.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';

/// Un pedido que llegó al negocio: cliente, dirección, productos y los
/// botones para avanzarlo (aceptar, preparar, listo, en camino, entregar).
class PedidoNegocioScreen extends StatelessWidget {
  const PedidoNegocioScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  Widget build(BuildContext context) {
    return ConNegocio(
      titulo: 'Pedido #$pedidoId',
      builder: (negocio) => _Detalle(negocio: negocio, pedidoId: pedidoId),
    );
  }
}

class _Detalle extends ConsumerStatefulWidget {
  const _Detalle({required this.negocio, required this.pedidoId});

  final Negocio negocio;
  final int pedidoId;

  @override
  ConsumerState<_Detalle> createState() => _DetalleState();
}

class _DetalleState extends ConsumerState<_Detalle> {
  bool _cambiando = false;

  ({int negocioId, int pedidoId}) get _id => (negocioId: widget.negocio.id, pedidoId: widget.pedidoId);

  Future<void> _avanzar(EstadoPedido estado) async {
    String? motivo;
    String? codigo;
    if (estado == EstadoPedido.rechazado || estado == EstadoPedido.cancelado) {
      motivo = await _pedirTexto(
        titulo: estado == EstadoPedido.rechazado ? '¿Por qué lo rechazas?' : '¿Por qué lo cancelas?',
        ayuda: 'El cliente verá este motivo. Ej.: "Nos quedamos sin stock".',
      );
      if (motivo == null) return;
    }
    if (estado == EstadoPedido.entregado) {
      codigo = await _pedirTexto(
        titulo: 'PIN del cliente',
        ayuda: 'Pídele al cliente su PIN de 4 números. Sin el PIN no se puede marcar como entregado.',
        pin: true,
      );
      if (codigo == null) return;
    }

    setState(() => _cambiando = true);
    try {
      await ref
          .read(miNegocioRepositoryProvider)
          .cambiarEstado(widget.negocio.id, widget.pedidoId, estado, motivo: motivo, codigo: codigo);
      ref.invalidate(pedidoNegocioProvider(_id));
      ref.invalidate(pedidosNegocioProvider);
      ref.invalidate(resumenNegocioProvider(widget.negocio.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido: ${estado.texto.toLowerCase()}')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.errorDe('codigo') ?? e.errorDe('motivo') ?? e.errorDe('estado') ?? e.mensaje),
        ));
      }
      ref.invalidate(pedidoNegocioProvider(_id));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  Future<String?> _pedirTexto({required String titulo, required String ayuda, bool pin = false}) async {
    final control = TextEditingController();
    final valor = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ayuda),
            const SizedBox(height: AppEspacios.m),
            TextField(
              key: Key(pin ? 'campo-pin' : 'campo-motivo'),
              controller: control,
              autofocus: true,
              keyboardType: pin ? TextInputType.number : TextInputType.text,
              maxLength: pin ? 4 : 255,
              inputFormatters: pin ? [FilteringTextInputFormatter.digitsOnly] : null,
              textAlign: pin ? TextAlign.center : TextAlign.start,
              style: pin ? Theme.of(contexto).textTheme.headlineMedium?.copyWith(letterSpacing: 12) : null,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, control.text.trim()), child: const Text('Confirmar')),
        ],
      ),
    );
    control.dispose();
    if (valor == null || valor.isEmpty) return null;
    return valor;
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoNegocioProvider(_id));
    final titulo = 'Pedido #${widget.pedidoId}';

    return pedido.when(
      skipLoadingOnRefresh: true,
      loading: () => Pantalla(titulo: titulo, child: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Pantalla(titulo: titulo, child: VistaError(error: e, alReintentar: () => ref.invalidate(pedidoNegocioProvider(_id)))),
      data: (p) {
        final textos = Theme.of(context).textTheme;
        // Botón principal: el siguiente paso; los demás (rechazar, cancelar) aparte.
        final avance = p.acciones.where((e) => !e.fallido).toList();
        final fallidos = p.acciones.where((e) => e.fallido).toList();

        return Pantalla(
          titulo: titulo,
          abajo: p.acciones.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.all(AppEspacios.m),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in avance)
                        BotonPrincipal(
                          key: Key('accion-${e.api}'),
                          texto: e.accion,
                          icono: e.icono,
                          cargando: _cambiando,
                          onPressed: () => _avanzar(e),
                        ),
                      for (final e in fallidos)
                        TextButton.icon(
                          key: Key('accion-${e.api}'),
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          onPressed: _cambiando ? null : () => _avanzar(e),
                          icon: Icon(e.icono),
                          label: Text('${e.accion} pedido'),
                        ),
                    ],
                  ),
                ),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(pedidoNegocioProvider(_id).future),
            child: ListView(
              padding: const EdgeInsets.all(AppEspacios.m),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppEspacios.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Recibido ${Formato.hace(p.creado)}', style: textos.bodyMedium)),
                            EtiquetaEstado(p.estado),
                          ],
                        ),
                        const Divider(height: AppEspacios.l),
                        _Dato(icono: Icons.person_outline, texto: p.clienteNombre ?? 'Cliente'),
                        if (p.clienteTelefono != null) _Dato(icono: Icons.phone_outlined, texto: p.clienteTelefono!, copiable: true),
                        _Dato(icono: Icons.place_outlined, texto: p.direccionEntrega, copiable: true),
                        if (p.referenciaEntrega != null) _Dato(icono: Icons.info_outline, texto: p.referenciaEntrega!),
                        if (p.distanciaKm != null)
                          _Dato(icono: Icons.route_outlined, texto: 'A unos ${p.distanciaKm!.toStringAsFixed(1)} km'),
                        if (p.notas != null) _Dato(icono: Icons.chat_bubble_outline, texto: 'Nota: ${p.notas}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppEspacios.m),
                const TituloSeccion('Productos', Icons.shopping_bag_outlined),
                DetalleMontos(pedido: p),
                const SizedBox(height: AppEspacios.m),
                Card(child: Padding(padding: const EdgeInsets.all(AppEspacios.m), child: LineaAvance(pedido: p))),
                if (p.estado == EstadoPedido.enCamino) ...[
                  const SizedBox(height: AppEspacios.m),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: const ListTile(
                      leading: Icon(Icons.pin_outlined),
                      title: Text('Al entregar, pide al cliente su PIN de 4 números.'),
                    ),
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

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, this.copiable = false});

  final IconData icono;
  final String texto;
  final bool copiable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppEspacios.s + 2),
          Expanded(child: Text(texto)),
          if (copiable)
            IconButton(
              tooltip: 'Copiar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: texto));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
              },
            ),
        ],
      ),
    );
  }
}
