import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/domain/pedido.dart';
import '../../pedidos/presentation/widgets/piezas_pedido.dart';
import '../data/mi_negocio_repository.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';
import 'widgets/cuenta_regresiva.dart';

/// Un pedido que llegó al negocio. Nuevo: Aceptar o Rechazar con la cuenta
/// regresiva del plazo. Aceptado: "Empezar a alistar"; alistando: se marcan
/// los productos y "Marcar como listo" se habilita con todos marcados. Lo
/// recoge y lo entrega un repartidor de la app: "Buscando repartidor…" o
/// "Lo lleva…".
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

  /// Productos que se acaban de marcar o desmarcar mientras responde la API
  /// (se ven marcados al instante).
  final _marcando = <int, bool>{};

  ({int negocioId, int pedidoId}) get _id => (negocioId: widget.negocio.id, pedidoId: widget.pedidoId);

  bool _alistado(ItemPedido i) => _marcando[i.id] ?? i.alistado;

  Future<void> _avanzar(EstadoPedido estado) async {
    // Un pedido nuevo se acepta o se rechaza (con motivo); una vez aceptado ya
    // no se cancela. El local llega hasta "listo"; recoger y entregar (con el
    // PIN) lo hace el repartidor.
    String? motivo;
    if (estado.fallido) {
      motivo = await showDialog<String>(
        context: context,
        builder: (_) =>
            DialogoMotivo(titulo: estado == EstadoPedido.rechazado ? '¿Por qué lo rechazas?' : '¿Por qué lo cancelas?'),
      );
      if (motivo == null) return;
    }

    setState(() => _cambiando = true);
    try {
      await ref
          .read(miNegocioRepositoryProvider)
          .cambiarEstado(widget.negocio.id, widget.pedidoId, estado, motivo: motivo);
      ref.invalidate(pedidoNegocioProvider(_id));
      ref.invalidate(pedidosNegocioProvider);
      ref.invalidate(resumenNegocioProvider(widget.negocio.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido: ${estado.texto.toLowerCase()}')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.errorDe('motivo') ?? e.errorDe('estado') ?? e.mensaje)));
      }
      ref.invalidate(pedidoNegocioProvider(_id));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  Future<void> _marcar(ItemPedido item, bool alistado) async {
    setState(() => _marcando[item.id] = alistado);
    try {
      await ref.read(miNegocioRepositoryProvider).marcarAlistado(widget.negocio.id, widget.pedidoId, item.id, alistado);
      ref.invalidate(pedidoNegocioProvider(_id));
      await ref.read(pedidoNegocioProvider(_id).future);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.errorDe('alistado') ?? e.mensaje)));
      }
      ref.invalidate(pedidoNegocioProvider(_id));
    } finally {
      if (mounted) setState(() => _marcando.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoNegocioProvider(_id));
    final titulo = 'Pedido #${widget.pedidoId}';

    return pedido.when(
      skipLoadingOnRefresh: true,
      loading: () => Pantalla(
        titulo: titulo,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Pantalla(
        titulo: titulo,
        child: VistaError(error: e, alReintentar: () => ref.invalidate(pedidoNegocioProvider(_id))),
      ),
      data: (p) {
        final textos = Theme.of(context).textTheme;
        final c = Theme.of(context).colorScheme;
        // Botón principal: el siguiente paso; rechazar aparte.
        final avance = p.acciones.where((e) => !e.fallido).toList();
        final fallidos = p.acciones.where((e) => e.fallido).toList();
        final alistando = p.estado == EstadoPedido.preparando;
        final listos = p.items.where(_alistado).length;
        final todoListo = p.items.isNotEmpty && listos == p.items.length;

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
                      // "Marcar como listo" recién con todos los productos marcados.
                      if (alistando && !todoListo)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppEspacios.s),
                          child: Text(
                            'Marca todos los productos para dejarlo listo ($listos de ${p.items.length}).',
                            key: const Key('falta-alistar'),
                            textAlign: TextAlign.center,
                            style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                          ),
                        ),
                      for (final e in avance)
                        BotonPrincipal(
                          key: Key('accion-${e.api}'),
                          texto: e.accion,
                          icono: e.icono,
                          cargando: _cambiando,
                          onPressed: e == EstadoPedido.listo && !todoListo ? null : () => _avanzar(e),
                        ),
                      for (final e in fallidos)
                        TextButton.icon(
                          key: Key('accion-${e.api}'),
                          style: TextButton.styleFrom(foregroundColor: c.error),
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
                if (p.estado == EstadoPedido.pendiente && p.aceptarAntes != null) ...[
                  Card(
                    color: c.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppEspacios.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pedido nuevo', style: textos.titleMedium?.copyWith(color: c.onPrimaryContainer)),
                          const SizedBox(height: AppEspacios.xs),
                          CuentaRegresiva(hasta: p.aceptarAntes!),
                          const SizedBox(height: AppEspacios.xs),
                          Text(
                            'El stock ya quedó reservado para este cliente.',
                            style: textos.bodySmall?.copyWith(color: c.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppEspacios.m),
                ],
                if (!p.estado.terminado && (p.tieneRepartidor || p.estado == EstadoPedido.listo)) ...[
                  EstadoReparto(pedido: p),
                  const SizedBox(height: AppEspacios.m),
                ],
                // Con QR: se acepta recién cuando el cliente pagó (la API no deja antes).
                if (p.esperandoPagoQr) ...[
                  Card(
                    key: const Key('esperando-pago-qr'),
                    color: c.tertiaryContainer,
                    child: const ListTile(
                      leading: Icon(Icons.qr_code_2),
                      title: Text('Esperando el pago con QR'),
                      subtitle: Text('Podrás aceptarlo cuando el cliente pague. Te llegará un aviso.'),
                    ),
                  ),
                  const SizedBox(height: AppEspacios.m),
                ],
                if (!p.estado.fallido && p.estado != EstadoPedido.pendiente) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppEspacios.m),
                      child: _Pasos(pedido: p, listos: listos),
                    ),
                  ),
                  const SizedBox(height: AppEspacios.m),
                ],
                if (alistando) ...[
                  _ListaAlistar(pedido: p, alistado: _alistado, alMarcar: _marcar),
                  const SizedBox(height: AppEspacios.m),
                ],
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
                        if (p.clienteTelefono != null)
                          _Dato(icono: Icons.phone_outlined, texto: p.clienteTelefono!, copiable: true),
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
                _Cobro(pedido: p),
                const SizedBox(height: AppEspacios.m),
                if (!alistando) ...[
                  const TituloSeccion('Productos', Icons.shopping_bag_outlined),
                  DetalleMontos(pedido: p),
                  const SizedBox(height: AppEspacios.m),
                ],
                if (p.estado.fallido)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppEspacios.m),
                      child: LineaAvance(pedido: p),
                    ),
                  ),
                const SizedBox(height: AppEspacios.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Aceptado → Alistando (x de n) → Listo, con la hora de cada paso.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.pedido, required this.listos});

  final Pedido pedido;
  final int listos;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final actual = EstadoPedido.camino.indexOf(pedido.estado);
    String hora(DateTime? f) =>
        f == null ? '' : '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
    final pasos = [
      (EstadoPedido.confirmado, 'Aceptado', hora(pedido.fechaDe(EstadoPedido.confirmado) ?? pedido.confirmado)),
      (
        EstadoPedido.preparando,
        'Alistando · $listos de ${pedido.items.length} productos',
        hora(pedido.fechaDe(EstadoPedido.preparando)),
      ),
      (EstadoPedido.listo, 'Listo · un repartidor lo recoge', hora(pedido.fechaDe(EstadoPedido.listo))),
    ];
    return Column(
      key: const Key('pasos-pedido'),
      children: [
        for (final (estado, texto, cuando) in pasos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  actual > EstadoPedido.camino.indexOf(estado)
                      ? Icons.check_circle
                      : actual == EstadoPedido.camino.indexOf(estado)
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: actual >= EstadoPedido.camino.indexOf(estado) ? c.primary : c.outline,
                ),
                const SizedBox(width: AppEspacios.s),
                Expanded(child: Text(texto, style: textos.bodyMedium)),
                if (cuando.isNotEmpty) Text(cuando, style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Alista los productos": se tocan para marcarlos a medida que se ponen en la bolsa.
class _ListaAlistar extends StatelessWidget {
  const _ListaAlistar({required this.pedido, required this.alistado, required this.alMarcar});

  final Pedido pedido;
  final bool Function(ItemPedido) alistado;
  final void Function(ItemPedido, bool) alMarcar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Card(
      key: const Key('lista-alistar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m, AppEspacios.m, 0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppEspacios.s,
              children: [
                Text('Alista los productos', style: textos.titleMedium),
                Text('Toca para marcar', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          for (final item in pedido.items)
            CheckboxListTile(
              key: Key('alistar-${item.id}'),
              value: alistado(item),
              onChanged: (v) => alMarcar(item, v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                item.nombre,
                style: alistado(item)
                    ? TextStyle(decoration: TextDecoration.lineThrough, color: c.onSurfaceVariant)
                    : null,
              ),
              subtitle: item.notas == null ? null : Text('Nota: ${item.notas}'),
              secondary: Text('×${item.cantidad}', style: textos.titleMedium),
            ),
          const SizedBox(height: AppEspacios.s),
        ],
      ),
    );
  }
}

/// Cuánto cobra el repartidor (efectivo, con el cambio) o cómo va el pago con QR.
class _Cobro extends StatelessWidget {
  const _Cobro({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final efectivo = pedido.metodoPago == 'efectivo';
    final detalle = efectivo && pedido.pagaCon != null
        ? 'Paga con ${Formato.bs(pedido.pagaCon)} · cambio ${Formato.bs(pedido.cambio)}'
        : pedido.estadoPagoTexto;
    return Card(
      key: const Key('cobro'),
      child: ListTile(
        leading: Icon(efectivo ? Icons.payments_outlined : Icons.qr_code_2),
        title: Text(efectivo ? 'Cobra el repartidor (efectivo)' : pedido.metodoPagoTexto),
        subtitle: detalle == null ? null : Text(detalle),
        trailing: Text(Formato.bs(pedido.total), style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// "Buscando repartidor… 3 cerca de tu tienda" o "Lo lleva Diego · Moto".
/// Se usa en el detalle y, en una línea ([compacto]), en la tarjeta de la lista.
class EstadoReparto extends StatelessWidget {
  const EstadoReparto({super.key, required this.pedido, this.compacto = false});

  final Pedido pedido;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final p = pedido;

    if (p.tieneRepartidor) {
      final detalle = [
        if (p.vehiculoTexto.isNotEmpty) p.vehiculoTexto,
        p.estado == EstadoPedido.enCamino ? 'Ya lo recogió y va camino al cliente.' : 'Va a tu local a recogerlo.',
      ].join(' · ');
      if (compacto) {
        return _Linea(
          key: const Key('lo-lleva'),
          icono: Icon(Icons.delivery_dining, size: 18, color: c.primary),
          texto: 'Lo lleva ${p.repartidorNombre}',
          detalle: detalle,
        );
      }
      return Card(
        key: const Key('lo-lleva'),
        color: c.primaryContainer,
        child: ListTile(
          leading: Icon(Icons.delivery_dining, color: c.onPrimaryContainer),
          title: Text(
            'Lo lleva ${p.repartidorNombre}',
            style: TextStyle(color: c.onPrimaryContainer, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(detalle, style: TextStyle(color: c.onPrimaryContainer)),
        ),
      );
    }

    final textoCerca = switch (p.repartidoresCerca) {
      null => 'Un repartidor de la app lo recogerá.',
      0 => 'Ahora no hay repartidores cerca de tu tienda. Te avisamos cuando alguien lo tome.',
      1 => '1 repartidor cerca de tu tienda',
      final n => '$n repartidores cerca de tu tienda',
    };
    final color = compacto ? c.primary : c.onSecondaryContainer;
    // Con "reducir movimiento", un ícono quieto en vez de la rueda que gira.
    final icono = AppMovimiento.activo(context)
        ? SizedBox.square(
            dimension: compacto ? 16 : 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
          )
        : Icon(Icons.search, size: compacto ? 18 : 24, color: color);

    if (compacto) {
      return _Linea(
        key: const Key('buscando-repartidor'),
        icono: icono,
        texto: 'Buscando repartidor…',
        detalle: textoCerca,
      );
    }
    return Card(
      key: const Key('buscando-repartidor'),
      color: c.secondaryContainer,
      child: ListTile(
        leading: icono,
        title: Text(
          'Buscando repartidor…',
          style: TextStyle(color: c.onSecondaryContainer, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$textoCerca\nLo entregará con el PIN del cliente.',
          key: const Key('repartidores-cerca'),
          style: TextStyle(color: c.onSecondaryContainer),
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({super.key, required this.icono, required this.texto, required this.detalle});

  final Widget icono;
  final String texto;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: icono),
        const SizedBox(width: AppEspacios.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto, style: textos.titleSmall),
              Text(detalle, style: textos.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Motivo para rechazar un pedido: un motivo rápido ("Sin stock", "Estamos
/// cerrando") o "Otro" con el texto. Con un motivo rápido el texto es un
/// detalle opcional. Devuelve el motivo que verá el cliente, o null si cancela.
class DialogoMotivo extends StatefulWidget {
  const DialogoMotivo({super.key, required this.titulo});

  final String titulo;

  /// Motivos rápidos: [clave del botón, texto que se envía].
  static const rapidos = [('sin-stock', 'Sin stock'), ('cerrando', 'Estamos cerrando'), ('otro', 'Otro')];

  @override
  State<DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<DialogoMotivo> {
  final _texto = TextEditingController();
  String? _elegido;

  bool get _esOtro => _elegido == 'Otro';
  String get _detalle => _texto.text.trim();

  /// "Otro" necesita el texto; los demás pueden ir solos o con un detalle.
  String? get _motivo {
    if (_elegido == null) return null;
    if (_esOtro) return _detalle.isEmpty ? null : _detalle;
    return _detalle.isEmpty ? _elegido : '$_elegido: $_detalle';
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motivo = _motivo;

    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('El cliente verá este motivo.'),
            const SizedBox(height: AppEspacios.m),
            Wrap(
              spacing: AppEspacios.s,
              runSpacing: AppEspacios.s,
              children: [
                for (final (clave, texto) in DialogoMotivo.rapidos)
                  ChoiceChip(
                    key: Key('motivo-$clave'),
                    label: Text(texto),
                    selected: _elegido == texto,
                    onSelected: (_) => setState(() => _elegido = texto),
                  ),
              ],
            ),
            const SizedBox(height: AppEspacios.m),
            TextField(
              key: const Key('campo-motivo'),
              controller: _texto,
              maxLength: 200,
              autofocus: _esOtro,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _esOtro ? 'Cuéntale al cliente qué pasó' : 'Detalle (opcional)',
                hintText: _esOtro ? 'Ej.: el producto llegó dañado' : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
        FilledButton(
          key: const Key('confirmar-motivo'),
          onPressed: motivo == null ? null : () => Navigator.pop(context, motivo),
          child: const Text('Confirmar'),
        ),
      ],
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
