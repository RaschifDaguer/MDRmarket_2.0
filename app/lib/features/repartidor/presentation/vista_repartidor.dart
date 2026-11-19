import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../pedidos/domain/pedido.dart';
import '../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../data/repartidor_repository.dart';
import '../domain/ganancias.dart';
import '../domain/pedido_disponible.dart';
import 'aviso_ubicacion.dart';
import 'cuenta_repartidor.dart';

/// Vista del repartidor aprobado: "Pedidos" (en línea, lo de hoy, su pedido
/// en curso y los disponibles), "Mis entregas" y "Cuenta" (pestañas abajo).
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
            children: [
              const _PedidosTab(),
              _pestana == 1 ? const _EntregasTab() : const SizedBox.shrink(),
              const CuentaRepartidor(),
            ],
          ),
        ),
        NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(Icons.delivery_dining),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Mis entregas',
            ),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
          ],
        ),
      ],
    );
  }
}

/// "Paquete chico" (Liviano), "Paquete mediano" o "Paquete grande".
String tamanoPaquete(String? tamano) => switch (tamano) {
  'Liviano' => 'Paquete chico',
  'Mediano' => 'Paquete mediano',
  'Grande' => 'Paquete grande',
  _ => tamano ?? 'Paquete',
};

/// "2,8 km".
String km(double valor) => '${valor.toStringAsFixed(1).replaceAll('.', ',')} km';

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

  Future<void> _editarMeta(double? actual) async {
    final mensajero = ScaffoldMessenger.of(context);
    final elegida = await showDialog<({double? meta})>(
      context: context,
      builder: (_) => _DialogoMeta(actual: actual),
    );
    if (elegida == null) return;
    try {
      await ref.read(repartidorRepositoryProvider).cambiarMeta(elegida.meta);
      ref.invalidate(gananciasProvider);
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.errorDe('meta_diaria') ?? e.mensaje)));
    }
  }

  Future<void> _actualizar() async {
    ref.invalidate(miRepartidorProvider);
    ref.invalidate(pedidoActualProvider);
    ref.invalidate(gananciasProvider);
    await ref.refresh(pedidosDisponiblesProvider.future).catchError((_) => const <PedidoDisponible>[]);
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(miRepartidorProvider).value;
    final enLinea = perfil?.disponible ?? false;
    final actual = ref.watch(pedidoActualProvider).value;
    final ganancias = ref.watch(gananciasProvider).value;
    final usuario = ref.watch(authControllerProvider).value;
    final vehiculo = perfil?.vehiculo;

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
                  // Manda su GPS mientras lleva un pedido (o avisa si falta el permiso).
                  const AvisoUbicacion(),
                  _Saludo(
                    nombre: usuario?.nombre,
                    vehiculo: vehiculo == null ? null : [vehiculo.tipoNombre, ?vehiculo.placa].join(' · '),
                  ),
                  const SizedBox(height: AppEspacios.m),
                  Aparecer(
                    orden: 1,
                    child: _InterruptorEnLinea(enLinea: enLinea, cambiando: _cambiandoLinea, alCambiar: _ponerEnLinea),
                  ),
                  const SizedBox(height: AppEspacios.m),
                  Aparecer(
                    orden: 2,
                    child: _Hoy(ganancias: ganancias, alEditarMeta: () => _editarMeta(ganancias?.metaDiaria)),
                  ),
                  if (actual != null) ...[
                    const SizedBox(height: AppEspacios.m),
                    Aparecer(orden: 3, child: _TarjetaEnCurso(actual)),
                  ],
                  const SizedBox(height: AppEspacios.m),
                  if (!enLinea)
                    const EstadoVacio(
                      icono: Icons.cloud_off_outlined,
                      titulo: 'Estás desconectado',
                      texto: 'Conéctate para ver pedidos cerca de ti.',
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

  List<Widget> _disponibles({required bool conPedido}) {
    final disponibles = ref.watch(pedidosDisponiblesProvider);
    return disponibles.when(
      skipLoadingOnRefresh: true,
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(AppEspacios.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
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
              TituloSeccion(
                'Cerca de ti · ${lista.length} ${lista.length == 1 ? 'pedido' : 'pedidos'}',
                Icons.near_me_outlined,
              ),
              for (final (i, p) in lista.indexed)
                Aparecer(
                  orden: 4 + i,
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

/// "Hola, Diego" con su vehículo.
class _Saludo extends StatelessWidget {
  const _Saludo({required this.nombre, required this.vehiculo});

  final String? nombre;
  final String? vehiculo;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final inicial = (nombre ?? '').isEmpty ? '?' : nombre!.characters.first.toUpperCase();
    return Row(
      key: const Key('saludo-repartidor'),
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: c.primary,
          child: Text(
            inicial,
            style: textos.titleMedium?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: AppEspacios.m - 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre == null ? 'Hola' : 'Hola, $nombre',
                style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (vehiculo != null) Text(vehiculo!, style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// El interruptor grande de "En línea".
class _InterruptorEnLinea extends StatelessWidget {
  const _InterruptorEnLinea({required this.enLinea, required this.cambiando, required this.alCambiar});

  final bool enLinea;
  final bool cambiando;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final fondo = enLinea ? c.primary : c.surfaceContainerHighest;
    final letra = enLinea ? c.onPrimary : c.onSurface;
    return Card(
      color: fondo,
      child: InkWell(
        onTap: cambiando ? null : () => alCambiar(!enLinea),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m, vertical: AppEspacios.m + 4),
          child: Row(
            children: [
              Icon(enLinea ? Icons.wifi_tethering : Icons.wifi_tethering_off, color: letra, size: 32),
              const SizedBox(width: AppEspacios.m - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enLinea ? 'En línea' : 'Desconectado',
                      style: textos.titleLarge?.copyWith(color: letra, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      enLinea ? 'Recibes pedidos cerca de ti' : 'No recibes pedidos',
                      style: textos.bodyMedium?.copyWith(color: letra),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.3,
                child: Switch(
                  key: const Key('interruptor-en-linea'),
                  value: enLinea,
                  onChanged: cambiando ? null : alCambiar,
                  activeThumbColor: c.onPrimary,
                  activeTrackColor: c.onPrimary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ganado hoy (con la meta del día, que se toca para cambiarla) y entregas de hoy.
class _Hoy extends StatelessWidget {
  const _Hoy({required this.ganancias, required this.alEditarMeta});

  final Ganancias? ganancias;
  final VoidCallback alEditarMeta;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final g = ganancias;
    final meta = g?.metaDiaria;
    final progreso = meta == null || g == null ? null : (g.ganadoHoy / meta).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Card(
            key: const Key('ganado-hoy'),
            child: InkWell(
              key: const Key('editar-meta'),
              onTap: alEditarMeta,
              child: Padding(
                padding: const EdgeInsets.all(AppEspacios.m - 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ganado hoy', style: textos.bodySmall),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formato.bs(g?.ganadoHoy ?? 0),
                        style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: AppEspacios.xs),
                    if (progreso != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: progreso, minHeight: 6),
                      ),
                      const SizedBox(height: AppEspacios.xs),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta == null ? 'Ponte una meta del día' : 'Meta del día ${Formato.bs(meta)}',
                            key: const Key('meta-del-dia'),
                            style: textos.bodySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.edit_outlined, size: 16, color: c.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppEspacios.s),
        Expanded(
          flex: 2,
          child: Card(
            key: const Key('entregas-hoy'),
            child: Padding(
              padding: const EdgeInsets.all(AppEspacios.m - 4),
              child: Column(
                children: [
                  Text('${g?.entregasHoy ?? 0}', style: textos.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text((g?.entregasHoy ?? 0) == 1 ? 'entrega' : 'entregas', style: textos.bodySmall),
                  Text('hoy', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cambiar la meta del día. Devuelve la meta (null = sin meta) o nada si cancela.
class _DialogoMeta extends StatefulWidget {
  const _DialogoMeta({required this.actual});

  final double? actual;

  @override
  State<_DialogoMeta> createState() => _DialogoMetaState();
}

class _DialogoMetaState extends State<_DialogoMeta> {
  late final _texto = TextEditingController(text: widget.actual?.toStringAsFixed(0) ?? '');
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _guardar() {
    final valor = double.tryParse(_texto.text.trim().replaceAll(',', '.'));
    if (valor == null || valor < 1 || valor > 10000) {
      setState(() => _error = 'Escribe un monto entre Bs 1 y Bs 10.000.');
      return;
    }
    Navigator.pop(context, (meta: valor));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meta del día'),
      content: TextField(
        key: const Key('campo-meta'),
        controller: _texto,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: '¿Cuánto quieres ganar hoy?', prefixText: 'Bs ', errorText: _error),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        if (widget.actual != null)
          TextButton(
            key: const Key('quitar-meta'),
            onPressed: () => Navigator.pop(context, (meta: null)),
            child: const Text('Quitar meta'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('guardar-meta'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _guardar,
          child: const Text('Guardar'),
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
                    Text(
                      '#${pedido.id} · ${pedido.negocioNombre}',
                      style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
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

/// Un pedido listo para aceptar: lo que gana, el recorrido y el tiempo, de qué
/// tienda a dónde, el tamaño y cuánto cobra (si es en efectivo).
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
    final recorrido = p.recorridoKm ?? p.distanciaKm;

    return Card(
      key: Key('disponible-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formato.bs(p.costoEnvio),
                  style: textos.headlineSmall?.copyWith(color: c.primary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: AppEspacios.s),
                Expanded(
                  child: Text(
                    [
                      if (recorrido != null) km(recorrido),
                      if (p.tiempoEstimadoMin != null) '~${p.tiempoEstimadoMin} min',
                    ].join(' · '),
                    key: Key('recorrido-${p.id}'),
                    textAlign: TextAlign.end,
                    style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (p.distanciaAlNegocioKm != null)
              Text(
                'La tienda está a ${km(p.distanciaAlNegocioKm!)} de ti',
                style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            const SizedBox(height: AppEspacios.s),
            Row(
              children: [
                Icon(Icons.storefront_outlined, size: 18, color: c.onSurfaceVariant),
                const SizedBox(width: AppEspacios.xs + 2),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: p.negocioNombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (p.negocioDireccion != null) TextSpan(text: ' · ${p.negocioDireccion}'),
                      ],
                    ),
                    style: textos.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
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
                Chip(
                  avatar: Icon(Icons.inventory_2_outlined, size: 16, color: c.onSurfaceVariant),
                  label: Text(tamanoPaquete(p.tamano)),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(
                    p.metodoPago == 'efectivo' ? Icons.payments_outlined : Icons.qr_code_2,
                    size: 16,
                    color: c.onSurfaceVariant,
                  ),
                  label: Text(p.metodoPago == 'efectivo' ? 'Cobras ${Formato.bs(p.total)}' : 'Pagado con QR'),
                  visualDensity: VisualDensity.compact,
                ),
                // Bebidas alcohólicas: al entregar, pide el carnet.
                if (p.soloMayores)
                  Chip(
                    key: Key('disponible-mayores-${p.id}'),
                    avatar: Icon(Icons.badge_outlined, size: 16, color: c.onErrorContainer),
                    label: Text('+18 · Pide carnet', style: TextStyle(color: c.onErrorContainer)),
                    backgroundColor: c.errorContainer,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppEspacios.m - 4),
            if (p.propio)
              // Su propia compra: se muestra para que sepa por qué no puede tomarla.
              Container(
                key: Key('propio-${p.id}'),
                padding: const EdgeInsets.all(AppEspacios.s + 2),
                decoration: BoxDecoration(
                  color: c.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadios.campo),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: c.onSecondaryContainer),
                    const SizedBox(width: AppEspacios.s),
                    Expanded(
                      child: Text(
                        'Es tu propio pedido: lo llevará otro repartidor.',
                        style: textos.bodyMedium?.copyWith(color: c.onSecondaryContainer),
                      ),
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
                label: const Text('Aceptar pedido'),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Mis entregas": lo de la semana, el total, la calificación, el gráfico por
/// día con el mejor día y la lista (tienda → dirección, hora, km y método).
class _EntregasTab extends ConsumerWidget {
  const _EntregasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entregas = ref.watch(entregasProvider);
    final ganancias = ref.watch(gananciasProvider).value;
    final textos = Theme.of(context).textTheme;

    return entregas.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(entregasProvider)),
      data: (datos) => RefreshIndicator(
        onRefresh: () {
          ref.invalidate(gananciasProvider);
          return ref.refresh(entregasProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m, AppEspacios.m, AppEspacios.xl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Mis entregas', style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppEspacios.m),
                    Row(
                      children: [
                        _Numero(
                          clave: 'semana-bs',
                          valor: Formato.bs(ganancias?.ganadoSemana ?? 0),
                          texto: 'Esta semana',
                        ),
                        const SizedBox(width: AppEspacios.s),
                        _Numero(
                          clave: 'total-entregas',
                          valor: '${ganancias?.totalEntregas ?? datos.total}',
                          texto: 'Entregas',
                        ),
                        const SizedBox(width: AppEspacios.s),
                        _Numero(
                          clave: 'calificacion',
                          valor: ganancias?.calificacion == null
                              ? '–'
                              : '★ ${ganancias!.calificacion!.toStringAsFixed(1)}',
                          texto: 'Calificación',
                        ),
                      ],
                    ),
                    if (ganancias != null) ...[const SizedBox(height: AppEspacios.m), _PorDia(ganancias)],
                    const SizedBox(height: AppEspacios.m),
                    if (datos.pedidos.isEmpty)
                      const EstadoVacio(
                        icono: Icons.history,
                        titulo: 'Todavía no entregaste pedidos',
                        texto: 'Aquí verás cada entrega con su hora y lo que ganaste.',
                      )
                    else
                      ..._lista(context, datos.pedidos),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Agrupadas por día: "Hoy", "Ayer" o la fecha.
  List<Widget> _lista(BuildContext context, List<Pedido> pedidos) {
    final textos = Theme.of(context).textTheme;
    final hoy = DateTime.now();
    String titulo(DateTime f) {
      final dia = DateTime(f.year, f.month, f.day);
      final diferencia = DateTime(hoy.year, hoy.month, hoy.day).difference(dia).inDays;
      return switch (diferencia) {
        0 => 'Hoy',
        1 => 'Ayer',
        _ => Formato.fecha(f),
      };
    }

    final widgets = <Widget>[];
    String? anterior;
    for (final p in pedidos) {
      final cuando = p.entregado ?? p.creado ?? hoy;
      final grupo = titulo(cuando);
      if (grupo != anterior) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: AppEspacios.s, bottom: AppEspacios.xs, left: 4),
            child: Text(grupo, style: textos.titleSmall),
          ),
        );
        anterior = grupo;
      }
      widgets.add(_FilaEntrega(pedido: p, cuando: cuando));
    }
    return widgets;
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.clave, required this.valor, required this.texto});

  final String clave;
  final String valor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        key: Key(clave),
        padding: const EdgeInsets.symmetric(vertical: AppEspacios.m - 4, horizontal: AppEspacios.s),
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: c.onPrimaryContainer),
              ),
            ),
            Text(texto, style: textos.bodySmall?.copyWith(color: c.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

/// Lo ganado cada día de esta semana (lunes a domingo) y el mejor día.
class _PorDia extends StatelessWidget {
  const _PorDia(this.ganancias);

  final Ganancias ganancias;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final dias = ganancias.porDia;
    final maximo = dias.fold<double>(1, (m, d) => math.max(m, d.ganado));
    final mejor = ganancias.mejorDia;

    return Card(
      key: const Key('grafico-por-dia'),
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Por día', style: textos.titleMedium)),
                if (ganancias.mejorDiaTexto != null)
                  Text(
                    'Mejor día: ${ganancias.mejorDiaTexto}',
                    key: const Key('mejor-dia'),
                    style: textos.bodySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: AppEspacios.m),
            SizedBox(
              height: 120,
              child: Semantics(
                label: 'Ganado por día: ${dias.map((d) => '${d.dia} ${Formato.bs(d.ganado)}').join(', ')}',
                child: BarChart(
                  BarChartData(
                    maxY: maximo * 1.1,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => c.inverseSurface,
                        getTooltipItem: (_, _, barra, _) =>
                            BarTooltipItem(Formato.bs(barra.toY), TextStyle(color: c.onInverseSurface, fontSize: 12)),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (valor, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(dias[valor.toInt()].dia, style: textos.labelSmall),
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < dias.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: dias[i].ganado,
                              width: 18,
                              // El mejor día, más fuerte.
                              color: mejor != null && DateUtils.isSameDay(dias[i].fecha, mejor)
                                  ? c.primary
                                  : c.primary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Con "reducir movimiento", sin la animación de las barras.
                  duration: AppMovimiento.activo(context) ? AppMovimiento.normal : Duration.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "TechStore SCZ → Calle Libertad 245 · 14:29 · 2,8 km · efectivo  +Bs 12".
class _FilaEntrega extends StatelessWidget {
  const _FilaEntrega({required this.pedido, required this.cuando});

  final Pedido pedido;
  final DateTime cuando;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final p = pedido;
    final hora = '${cuando.hour.toString().padLeft(2, '0')}:${cuando.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        key: Key('entrega-${p.id}'),
        leading: ImagenRed(p.negocioLogo, ancho: 40, alto: 40, radio: 10, icono: Icons.storefront),
        title: Text('${p.negocioNombre} → ${p.direccionEntrega}', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [hora, if (p.distanciaKm != null) km(p.distanciaKm!), p.metodoPago == 'qr' ? 'QR' : 'efectivo'].join(' · '),
        ),
        trailing: Text(
          '+${Formato.bs(p.costoEnvio)}',
          style: textos.titleSmall?.copyWith(color: c.primary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
