import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/domain/pedido.dart';
import '../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../data/repartidor_repository.dart';
import '../domain/pedido_disponible.dart';

/// Vista del repartidor aprobado: "Pedidos" (en línea, su pedido en curso y
/// los disponibles para aceptar) y "Mis entregas" (pestañas abajo).
class VistaRepartidor extends StatefulWidget {
  const VistaRepartidor({super.key});

  @override
  State<VistaRepartidor> createState() => _VistaRepartidorState();
}

class _VistaRepartidorState extends State<VistaRepartidor> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _pestana,
            // "Mis entregas" se arma recién al abrirla.
            children: [const _PedidosTab(), _pestana == 1 ? const _EntregasTab() : const SizedBox.shrink()],
          ),
        ),
        NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Pedidos'),
            NavigationDestination(
                icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Mis entregas'),
          ],
        ),
      ],
    );
  }
}

class _PedidosTab extends ConsumerStatefulWidget {
  const _PedidosTab();

  @override
  ConsumerState<_PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends ConsumerState<_PedidosTab> {
  bool _cambiandoLinea = false;
  int? _aceptando;

  Future<void> _ponerEnLinea(bool valor) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _cambiandoLinea = true);
    try {
      // Con GPS, los pedidos salen del negocio más cercano al más lejano.
      final ubicacion = valor ? await ref.read(ubicacionActualProvider)() : null;
      await ref.read(repartidorRepositoryProvider).ponerDisponible(valor, ubicacion: ubicacion);
      ref.invalidate(miRepartidorProvider);
      ref.invalidate(pedidosDisponiblesProvider);
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _cambiandoLinea = false);
    }
  }

  Future<void> _aceptar(PedidoDisponible p) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _aceptando = p.id);
    try {
      await ref.read(repartidorRepositoryProvider).aceptar(p.id);
      ref.invalidate(pedidoActualProvider);
      ref.invalidate(pedidosDisponiblesProvider);
      if (mounted) context.push('/repartidor/pedido');
    } on ApiException catch (e) {
      // Ej. "Otro repartidor ya aceptó este pedido.": se actualiza la lista.
      mensajero.showSnackBar(SnackBar(content: Text(e.errorDe('pedido') ?? e.mensaje)));
      ref.invalidate(pedidosDisponiblesProvider);
    } finally {
      if (mounted) setState(() => _aceptando = null);
    }
  }

  Future<void> _actualizar() async {
    ref.invalidate(miRepartidorProvider);
    ref.invalidate(pedidoActualProvider);
    await ref.refresh(pedidosDisponiblesProvider.future).catchError((_) => const <PedidoDisponible>[]);
  }

  @override
  Widget build(BuildContext context) {
    final enLinea = ref.watch(miRepartidorProvider).value?.disponible ?? false;
    final actual = ref.watch(pedidoActualProvider).value;

    return RefreshIndicator(
      onRefresh: _actualizar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m, AppEspacios.m, AppEspacios.xl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Aparecer(orden: 1, child: _interruptor(enLinea)),
                  if (actual != null) ...[
                    const SizedBox(height: AppEspacios.m),
                    Aparecer(orden: 2, child: _TarjetaEnCurso(actual)),
                  ],
                  const SizedBox(height: AppEspacios.m),
                  if (!enLinea)
                    const EstadoVacio(
                      icono: Icons.cloud_off_outlined,
                      titulo: 'Estás desconectado',
                      texto: 'Activa "En línea" para ver los pedidos listos cerca de ti.',
                    )
                  else
                    ..._disponibles(conPedido: actual != null),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interruptor(bool enLinea) {
    final c = Theme.of(context).colorScheme;
    return Card(
      color: enLinea ? c.primaryContainer : null,
      child: SwitchListTile(
        key: const Key('interruptor-en-linea'),
        value: enLinea,
        onChanged: _cambiandoLinea ? null : _ponerEnLinea,
        secondary: Icon(enLinea ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: enLinea ? c.onPrimaryContainer : c.onSurfaceVariant),
        title: Text(enLinea ? 'En línea' : 'Desconectado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: enLinea ? c.onPrimaryContainer : null)),
        subtitle: Text(enLinea ? 'Recibes pedidos cerca de ti' : 'No recibes pedidos',
            style: TextStyle(color: enLinea ? c.onPrimaryContainer : c.onSurfaceVariant)),
      ),
    );
  }

  List<Widget> _disponibles({required bool conPedido}) {
    final disponibles = ref.watch(pedidosDisponiblesProvider);
    return disponibles.when(
      skipLoadingOnRefresh: true,
      loading: () => const [Padding(padding: EdgeInsets.all(AppEspacios.xl), child: Center(child: CircularProgressIndicator()))],
      error: (e, _) => [VistaError(error: e, alReintentar: () => ref.invalidate(pedidosDisponiblesProvider))],
      data: (lista) => lista.isEmpty
          ? const [
              EstadoVacio(
                icono: Icons.inventory_2_outlined,
                titulo: 'No hay pedidos listos por ahora',
                texto: 'Desliza hacia abajo para actualizar.',
              ),
            ]
          : [
              TituloSeccion('Pedidos disponibles (${lista.length})', Icons.delivery_dining_outlined),
              for (final (i, p) in lista.indexed)
                Aparecer(
                  orden: 3 + i,
                  child: _TarjetaDisponible(
                    pedido: p,
                    aceptando: _aceptando == p.id,
                    // Un solo pedido a la vez: con uno en curso no se puede aceptar otro.
                    alAceptar: conPedido || _aceptando != null ? null : () => _aceptar(p),
                  ),
                ),
            ],
    );
  }
}

/// Su pedido en curso, arriba de la lista, para volver a abrirlo.
class _TarjetaEnCurso extends StatelessWidget {
  const _TarjetaEnCurso(this.pedido);

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Tarjeta3D(
      inclinacionMax: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.delivery_dining, color: c.primary, size: 32),
              const SizedBox(width: AppEspacios.m - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu pedido en curso', style: textos.titleMedium),
                    Text('#${pedido.id} · ${pedido.negocioNombre}', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              EtiquetaEstado(pedido.estado),
            ],
          ),
          const SizedBox(height: AppEspacios.m - 4),
          FilledButton.icon(
            key: const Key('ver-pedido-actual'),
            onPressed: () => context.push('/repartidor/pedido'),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Ver pedido'),
          ),
        ],
      ),
    );
  }
}

/// Un pedido listo para aceptar: negocio, destino, distancias, tamaño y envío.
class _TarjetaDisponible extends StatelessWidget {
  const _TarjetaDisponible({required this.pedido, required this.aceptando, required this.alAceptar});

  final PedidoDisponible pedido;
  final bool aceptando;
  final VoidCallback? alAceptar;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final p = pedido;

    Widget chip(IconData icono, String texto) => Chip(
          avatar: Icon(icono, size: 16, color: c.onSurfaceVariant),
          label: Text(texto),
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: c.outlineVariant),
        );

    return Card(
      key: Key('disponible-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImagenRed(p.negocioLogo, ancho: 44, alto: 44, radio: 12, icono: Icons.storefront),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.negocioNombre, style: textos.titleMedium),
                      if (p.negocioDireccion != null)
                        Text(p.negocioDireccion!, style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Formato.bs(p.costoEnvio), style: textos.titleMedium?.copyWith(color: c.primary)),
                    Text('envío', style: textos.labelSmall?.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppEspacios.s),
            Row(
              children: [
                Icon(Icons.home_outlined, size: 18, color: c.onSurfaceVariant),
                const SizedBox(width: AppEspacios.xs + 2),
                Expanded(child: Text(p.direccionEntrega, style: textos.bodyMedium)),
              ],
            ),
            const SizedBox(height: AppEspacios.s),
            Wrap(
              spacing: AppEspacios.s,
              runSpacing: AppEspacios.xs,
              children: [
                if (p.distanciaAlNegocioKm != null)
                  chip(Icons.near_me_outlined, 'A ${p.distanciaAlNegocioKm!.toStringAsFixed(1)} km de ti'),
                if (p.distanciaKm != null) chip(Icons.route_outlined, 'Recorrido ${p.distanciaKm!.toStringAsFixed(1)} km'),
                if (p.tamano != null) chip(Icons.inventory_2_outlined, p.tamano!),
                if (p.metodoPago == 'efectivo') chip(Icons.payments_outlined, 'Cobrar ${Formato.bs(p.total)}'),
              ],
            ),
            const SizedBox(height: AppEspacios.m - 4),
            if (p.propio)
              // Su propia compra: se muestra para que sepa por qué no puede tomarla.
              Container(
                key: Key('propio-${p.id}'),
                padding: const EdgeInsets.all(AppEspacios.s + 2),
                decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(AppRadios.campo)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: c.onSecondaryContainer),
                    const SizedBox(width: AppEspacios.s),
                    Expanded(
                      child: Text('Es tu propio pedido: lo llevará otro repartidor.',
                          style: textos.bodyMedium?.copyWith(color: c.onSecondaryContainer)),
                    ),
                  ],
                ),
              )
            else
              FilledButton.icon(
                key: Key('aceptar-${p.id}'),
                onPressed: aceptando ? null : alAceptar,
                icon: aceptando
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Aceptar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntregasTab extends ConsumerWidget {
  const _EntregasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entregas = ref.watch(entregasProvider);
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return entregas.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(entregasProvider)),
      data: (datos) => RefreshIndicator(
        onRefresh: () => ref.refresh(entregasProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m, AppEspacios.m, AppEspacios.xl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: c.primaryContainer,
                      child: ListTile(
                        leading: Icon(Icons.emoji_events_outlined, color: c.onPrimaryContainer),
                        title: Text(
                          datos.total == 1 ? '1 entrega' : '${datos.total} entregas',
                          style: textos.titleMedium?.copyWith(color: c.onPrimaryContainer),
                        ),
                        subtitle: Text('${Formato.bs(datos.totalEnvios)} en envíos',
                            style: TextStyle(color: c.onPrimaryContainer)),
                      ),
                    ),
                    const SizedBox(height: AppEspacios.m),
                    if (datos.pedidos.isEmpty)
                      const EstadoVacio(
                        icono: Icons.history,
                        titulo: 'Todavía no entregaste pedidos',
                        texto: 'Aquí verás cada entrega con su fecha y lo que ganaste.',
                      )
                    else
                      for (final p in datos.pedidos)
                        Card(
                          child: ListTile(
                            leading: ImagenRed(p.negocioLogo, ancho: 40, alto: 40, radio: 10, icono: Icons.storefront),
                            title: Text(p.negocioNombre),
                            subtitle: Text('#${p.id} · ${Formato.fechaHora(p.entregado ?? p.creado)}'),
                            trailing: Text(Formato.bs(p.costoEnvio), style: textos.titleSmall?.copyWith(color: c.primary)),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
