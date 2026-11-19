import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/formato/formato.dart';
import '../../../core/maps/coordenada.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/domain/pedido.dart';
import '../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../data/envio_ubicacion.dart';
import '../data/repartidor_repository.dart';
import 'aviso_ubicacion.dart';
import 'entregar_pin_screen.dart' show AvisoCarnet;
import 'mapa_reparto.dart';
import 'vista_repartidor.dart' show km;

/// Abre un enlace fuera de la app (Google Maps). Las pruebas lo reemplazan.
final abrirEnlaceProvider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// "Cómo llegar": Google Maps con el destino (por coordenadas o, si no hay,
/// por la dirección escrita). En bicicleta, la ruta para bicicleta.
Uri enlaceComoLlegar({Coordenada? destino, String? direccion, bool bicicleta = false}) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destino == null ? (direccion ?? '') : '${destino.latitud},${destino.longitud}',
      'travelmode': bicicleta ? 'bicycling' : 'driving',
    });

/// El pedido que lleva el repartidor, en 2 pasos: 1 Recoger (mapa, la tienda,
/// "Cómo llegar", "Ya lo recogí" y "Soltar pedido") y 2 Entregar (la casa del
/// cliente, cuánto cobrar y "Entregar", que pide el PIN).
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
    ref.invalidate(gananciasProvider);
  }

  Future<void> _recogido(Pedido p) async {
    await _hacer(() => ref.read(repartidorRepositoryProvider).cambiarEstado(p.id, EstadoPedido.enCamino));
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

  Future<void> _comoLlegar(Pedido p) async {
    final recogido = p.estado == EstadoPedido.enCamino;
    final vehiculo = ref.read(miRepartidorProvider).value?.vehiculo?.tipoCodigo;
    final enlace = enlaceComoLlegar(
      destino: recogido ? p.destino : p.negocioUbicacion,
      direccion: recogido ? p.direccionEntrega : (p.negocioDireccion ?? p.negocioNombre),
      bicicleta: vehiculo == 'bicicleta',
    );
    final mensajero = ScaffoldMessenger.of(context);
    if (!await ref.read(abrirEnlaceProvider)(enlace)) {
      mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir Google Maps.')));
    }
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
      loading: () => const Pantalla(
        titulo: titulo,
        child: Center(child: CircularProgressIndicator()),
      ),
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
    final recogido = p.estado == EstadoPedido.enCamino;
    return Padding(
      padding: const EdgeInsets.all(AppEspacios.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  key: const Key('como-llegar'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: () => _comoLlegar(p),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Cómo llegar'),
                ),
              ),
              const SizedBox(width: AppEspacios.s),
              Expanded(
                flex: 3,
                child: p.estado == EstadoPedido.listo
                    ? BotonPrincipal(
                        key: const Key('boton-recogido'),
                        texto: 'Ya lo recogí',
                        icono: Icons.inventory_2_outlined,
                        cargando: _cambiando,
                        onPressed: () => _recogido(p),
                      )
                    : BotonPrincipal(
                        key: const Key('boton-entregado'),
                        texto: 'Entregar',
                        icono: Icons.pin_outlined,
                        onPressed: recogido ? () => context.push('/repartidor/entregar') : null,
                      ),
              ),
            ],
          ),
          if (p.estado == EstadoPedido.listo)
            TextButton.icon(
              key: const Key('boton-soltar'),
              style: TextButton.styleFrom(foregroundColor: c.error),
              onPressed: _cambiando ? null : () => _soltar(p),
              icon: const Icon(Icons.undo),
              label: const Text('Soltar pedido'),
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
    final yo = ref.watch(miUbicacionProvider);
    final hacia = recogido ? p.destino : p.negocioUbicacion;
    final distancia = yo != null && hacia != null ? yo.distanciaKm(hacia) : null;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(pedidoActualProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          // Manda su GPS al cliente (o avisa si falta el permiso de ubicación).
          const AvisoUbicacion(),
          // Dónde está él, la tienda y la casa del cliente, con la línea del recorrido.
          MapaReparto(pedido: p, alto: 240),
          const SizedBox(height: AppEspacios.s),
          _Pasos(recogido: recogido),
          const SizedBox(height: AppEspacios.m),
          Card(
            key: Key(recogido ? 'destino-cliente' : 'destino-tienda'),
            color: c.secondaryContainer,
            child: ListTile(
              leading: recogido
                  ? Icon(Icons.home_outlined, color: c.onSecondaryContainer, size: 32)
                  : ImagenRed(p.negocioLogo, ancho: 44, alto: 44, radio: 12, icono: Icons.storefront),
              title: Text(
                recogido ? (p.clienteNombre ?? 'Cliente') : p.negocioNombre,
                style: textos.titleMedium?.copyWith(color: c.onSecondaryContainer),
              ),
              subtitle: Text(
                [
                  recogido ? p.direccionEntrega : (p.negocioDireccion ?? 'Ve a la tienda a recogerlo'),
                  if (distancia != null) 'a ${km(distancia)}',
                ].join(' · '),
                key: const Key('destino-detalle'),
                style: TextStyle(color: c.onSecondaryContainer),
              ),
              trailing: EtiquetaEstado(p.estado),
            ),
          ),
          if (recogido && p.referenciaEntrega != null)
            _Dato(icono: Icons.info_outline, texto: 'Referencia: ${p.referenciaEntrega}'),
          if (recogido && p.clienteTelefono != null) _Dato(icono: Icons.phone_outlined, texto: p.clienteTelefono!),
          if (!recogido && p.negocioTelefono != null) _Dato(icono: Icons.phone_outlined, texto: p.negocioTelefono!),
          if (!recogido)
            _Dato(
              icono: Icons.person_outline,
              texto: 'Para ${p.clienteNombre ?? 'el cliente'} · ${p.direccionEntrega}',
            ),
          if (p.notas != null) _Dato(icono: Icons.chat_bubble_outline, texto: 'Nota: ${p.notas}'),
          const SizedBox(height: AppEspacios.s),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    title: Text('Pedido', style: textos.bodySmall),
                    subtitle: Text(
                      '#${p.id} · ${p.unidades} producto${p.unidades == 1 ? '' : 's'}',
                      style: textos.titleSmall,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  key: const Key('cobras-al-cliente'),
                  color: efectivo ? c.tertiaryContainer : null,
                  child: ListTile(
                    title: Text('Cobras al cliente', style: textos.bodySmall),
                    subtitle: Text(
                      efectivo ? '${Formato.bs(p.total)} efectivo' : 'Nada (pagó con QR)',
                      style: textos.titleSmall?.copyWith(color: efectivo ? c.onTertiaryContainer : null),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text('Tu envío: ${Formato.bs(p.costoEnvio)}', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          if (p.soloMayores) ...[const SizedBox(height: AppEspacios.s), const AvisoCarnet()],
          const SizedBox(height: AppEspacios.m),
          const TituloSeccion('Productos', Icons.shopping_bag_outlined),
          DetalleMontos(pedido: p),
          const SizedBox(height: AppEspacios.xl),
        ],
      ),
    );
  }
}

/// 1 Recoger → 2 Entregar.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.recogido});

  final bool recogido;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    Widget paso(int numero, String texto, {required bool actual, required bool hecho}) => Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: actual || hecho ? c.primary : c.surfaceContainerHighest,
            child: hecho
                ? Icon(Icons.check, size: 16, color: c.onPrimary)
                : Text('$numero', style: textos.labelLarge?.copyWith(color: actual ? c.onPrimary : c.onSurfaceVariant)),
          ),
          const SizedBox(width: AppEspacios.s),
          Text(texto, style: textos.titleSmall?.copyWith(color: actual ? c.primary : null)),
        ],
      ),
    );
    return Semantics(
      label: recogido ? 'Paso 2 de 2: entregar' : 'Paso 1 de 2: recoger',
      child: Row(
        key: const Key('pasos-reparto'),
        children: [
          paso(1, 'Recoger', actual: !recogido, hecho: recogido),
          paso(2, 'Entregar', actual: recogido, hecho: false),
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
