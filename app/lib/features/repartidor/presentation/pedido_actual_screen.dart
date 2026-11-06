import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/domain/pedido.dart';
import '../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../data/repartidor_repository.dart';
import 'aviso_ubicacion.dart';
import 'dialogo_pin.dart';

/// El pedido que lleva el repartidor: dónde recogerlo, a quién entregarlo,
/// cuánto cobrar y los botones "Recogido", "Entregado" (con el PIN) y
/// "Soltar pedido" (solo antes de recogerlo).
class PedidoActualScreen extends ConsumerStatefulWidget {
  const PedidoActualScreen({super.key});

  @override
  ConsumerState<PedidoActualScreen> createState() => _PedidoActualScreenState();
}

class _PedidoActualScreenState extends ConsumerState<PedidoActualScreen> {
  bool _cambiando = false;

  void _refrescarTodo() {
    ref.invalidate(pedidoActualProvider);
    ref.invalidate(pedidosDisponiblesProvider);
    ref.invalidate(entregasProvider);
  }

  Future<void> _recogido(Pedido p) async {
    await _hacer(() => ref.read(repartidorRepositoryProvider).cambiarEstado(p.id, EstadoPedido.enCamino));
  }

  Future<void> _entregar(Pedido p) async {
    final mensajero = ScaffoldMessenger.of(context);
    String? error;
    // Si el PIN no coincide, se vuelve a pedir mostrando el error.
    while (mounted) {
      final pin = await pedirPin(context, error: error);
      if (pin == null) return;
      setState(() => _cambiando = true);
      try {
        await ref.read(repartidorRepositoryProvider).cambiarEstado(p.id, EstadoPedido.entregado, codigo: pin);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _cambiando = false);
        error = e.errorDe('codigo');
        if (error == null) {
          mensajero.showSnackBar(SnackBar(content: Text(e.errorDe('estado') ?? e.mensaje)));
          _refrescarTodo();
          return;
        }
        continue;
      }
      _refrescarTodo();
      if (!mounted) return;
      mensajero.showSnackBar(const SnackBar(content: Text('¡Pedido entregado! Lo verás en "Mis entregas".')));
      context.go('/inicio');
      return;
    }
  }

  Future<void> _soltar(Pedido p) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Soltar este pedido?'),
        content: const Text('Volverá a la lista para que lo lleve otro repartidor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Sí, soltarlo'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;
    final listo = await _hacer(() => ref.read(repartidorRepositoryProvider).soltar(p.id));
    if (listo && mounted) context.go('/inicio');
  }

  /// Ejecuta un cambio y refresca; los errores de la API van en un aviso abajo.
  Future<bool> _hacer(Future<Object?> Function() cambio) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _cambiando = true);
    try {
      await cambio();
      _refrescarTodo();
      return true;
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.errorDe('pedido') ?? e.errorDe('estado') ?? e.mensaje)));
      _refrescarTodo();
      return false;
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const titulo = 'Mi pedido en curso';
    final pedido = ref.watch(pedidoActualProvider);

    return pedido.when(
      skipLoadingOnRefresh: true,
      loading: () => const Pantalla(titulo: titulo, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Pantalla(
        titulo: titulo,
        child: VistaError(error: e, alReintentar: () => ref.invalidate(pedidoActualProvider)),
      ),
      data: (p) => p == null
          ? Pantalla(
              titulo: titulo,
              child: EstadoVacio(
                icono: Icons.delivery_dining_outlined,
                titulo: 'No tienes un pedido en curso',
                texto: 'Acepta uno de la lista de pedidos disponibles.',
                accion: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => context.go('/inicio'),
                  child: const Text('Ver pedidos disponibles'),
                ),
              ),
            )
          : Pantalla(titulo: 'Pedido #${p.id}', abajo: _botones(p), child: _detalle(p)),
    );
  }

  Widget _botones(Pedido p) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppEspacios.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.estado == EstadoPedido.listo) ...[
            BotonPrincipal(
              key: const Key('boton-recogido'),
              texto: 'Recogido',
              icono: Icons.inventory_2_outlined,
              cargando: _cambiando,
              onPressed: () => _recogido(p),
            ),
            TextButton.icon(
              key: const Key('boton-soltar'),
              style: TextButton.styleFrom(foregroundColor: c.error),
              onPressed: _cambiando ? null : () => _soltar(p),
              icon: const Icon(Icons.undo),
              label: const Text('Soltar pedido'),
            ),
          ] else if (p.estado == EstadoPedido.enCamino)
            BotonPrincipal(
              key: const Key('boton-entregado'),
              texto: 'Entregado',
              icono: Icons.check_circle_outline,
              cargando: _cambiando,
              onPressed: () => _entregar(p),
            ),
        ],
      ),
    );
  }

  Widget _detalle(Pedido p) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final recogido = p.estado == EstadoPedido.enCamino;
    final efectivo = p.metodoPago == 'efectivo';

    return RefreshIndicator(
      onRefresh: () => ref.refresh(pedidoActualProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          // Manda su GPS al cliente (o avisa si falta el permiso de ubicación).
          const AvisoUbicacion(),
          // Qué hacer ahora.
          Card(
            color: c.secondaryContainer,
            child: ListTile(
              leading: Icon(recogido ? Icons.home_outlined : Icons.storefront_outlined, color: c.onSecondaryContainer),
              title: Text(recogido ? 'Llévalo a la casa del cliente' : 'Ve al negocio a recogerlo',
                  style: textos.titleMedium?.copyWith(color: c.onSecondaryContainer)),
              subtitle: Text(
                recogido ? 'Al entregarlo, pídele su PIN de 4 números.' : 'Cuando te lo den, toca "Recogido".',
                style: TextStyle(color: c.onSecondaryContainer),
              ),
              trailing: EtiquetaEstado(p.estado),
            ),
          ),
          const SizedBox(height: AppEspacios.m),
          const TituloSeccion('Recoger en', Icons.storefront_outlined),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: ImagenRed(p.negocioLogo, ancho: 40, alto: 40, radio: 10, icono: Icons.storefront),
                  title: Text(p.negocioNombre, style: textos.titleMedium),
                ),
                if (p.negocioTelefono != null) _Dato(icono: Icons.phone_outlined, texto: p.negocioTelefono!),
              ],
            ),
          ),
          const SizedBox(height: AppEspacios.m),
          const TituloSeccion('Entregar a', Icons.home_outlined),
          Card(
            child: Column(
              children: [
                _Dato(icono: Icons.person_outline, texto: p.clienteNombre ?? 'Cliente'),
                if (p.clienteTelefono != null) _Dato(icono: Icons.phone_outlined, texto: p.clienteTelefono!),
                _Dato(icono: Icons.place_outlined, texto: p.direccionEntrega),
                if (p.referenciaEntrega != null) _Dato(icono: Icons.info_outline, texto: p.referenciaEntrega!),
                if (p.distanciaKm != null)
                  _Dato(icono: Icons.route_outlined, texto: 'A unos ${p.distanciaKm!.toStringAsFixed(1)} km del negocio'),
                if (p.notas != null) _Dato(icono: Icons.chat_bubble_outline, texto: 'Nota: ${p.notas}'),
              ],
            ),
          ),
          const SizedBox(height: AppEspacios.m),
          Card(
            color: efectivo ? c.tertiaryContainer : c.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(efectivo ? Icons.payments_outlined : Icons.check_circle_outline,
                  color: efectivo ? c.onTertiaryContainer : c.onSurfaceVariant),
              title: Text(
                efectivo ? 'Cobra ${Formato.bs(p.total)} en efectivo' : '${p.metodoPagoTexto}: no cobres nada',
                style: textos.titleSmall?.copyWith(color: efectivo ? c.onTertiaryContainer : c.onSurface),
              ),
              subtitle: Text('Tu envío: ${Formato.bs(p.costoEnvio)}',
                  style: TextStyle(color: efectivo ? c.onTertiaryContainer : c.onSurfaceVariant)),
            ),
          ),
          const SizedBox(height: AppEspacios.m),
          const TituloSeccion('Productos', Icons.shopping_bag_outlined),
          DetalleMontos(pedido: p),
          const SizedBox(height: AppEspacios.xl),
        ],
      ),
    );
  }
}

/// Una fila de dato con ícono; se copia con un toque largo.
class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icono, size: 20),
      title: Text(texto),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: texto));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
      },
    );
  }
}
