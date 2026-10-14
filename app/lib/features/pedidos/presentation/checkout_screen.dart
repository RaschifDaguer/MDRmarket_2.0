import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../carrito/domain/carrito.dart';
import '../../carrito/presentation/carrito_controller.dart';
import '../data/pedidos_repository.dart';
import '../domain/direccion.dart';
import 'direccion_sheet.dart';

/// Último paso: dónde entregar, cómo pagar y confirmar el pedido.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notas = TextEditingController();
  Direccion? _direccion;
  String _metodoPago = 'efectivo';
  Cotizacion? _cotizacion;
  String? _errorEnvio;
  bool _cotizando = false;
  bool _enviando = false;
  String? _errorGeneral;

  @override
  void initState() {
    super.initState();
    // Al llegar las direcciones guardadas, se elige la predeterminada.
    ref.listenManual(direccionesProvider, (_, siguiente) {
      final lista = siguiente.value;
      if (_direccion == null && lista != null && lista.isNotEmpty) {
        _elegir(lista.firstWhere((d) => d.predeterminada, orElse: () => lista.first));
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _elegir(Direccion direccion) async {
    final carrito = ref.read(carritoProvider);
    if (carrito == null) return;
    setState(() {
      _direccion = direccion;
      _cotizacion = null;
      _errorEnvio = null;
      _cotizando = true;
    });
    try {
      final cotizacion = await ref.read(pedidosRepositoryProvider).cotizar(
            carrito.negocio.id,
            direccion.ubicacion,
            carrito.items.map((i) => i.producto.id).toList(),
          );
      if (mounted && _direccion == direccion) setState(() => _cotizacion = cotizacion);
    } on ApiException catch (e) {
      if (mounted && _direccion == direccion) {
        setState(() => _errorEnvio = e.errorDe('latitud') ?? e.errorDe('negocio_id') ?? e.mensaje);
      }
    } finally {
      if (mounted && _direccion == direccion) setState(() => _cotizando = false);
    }
  }

  Future<void> _confirmar(Carrito carrito) async {
    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });
    final router = GoRouter.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final pedido = await ref.read(pedidosRepositoryProvider).crear(
            carrito,
            (direccionId: _direccion!.id, direccion: null, referencia: null, ubicacion: null),
            metodoPago: _metodoPago,
            notas: _notas.text,
          );
      ref.read(carritoProvider.notifier).vaciar();
      ref.invalidate(misPedidosProvider);
      mensajero.showSnackBar(const SnackBar(content: Text('¡Pedido enviado! Te avisaremos cuando el negocio lo acepte.')));
      router.go('/inicio');
      router.push('/pedido/${pedido.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        // El primer error que mande la API (stock, mínimo, cobertura…) o el mensaje general.
        _errorGeneral = e.errores.values.firstOrNull?.firstOrNull ?? e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);
    if (carrito == null || carrito.vacio) {
      return const Pantalla(
        titulo: 'Confirmar pedido',
        child: EstadoVacio(icono: Icons.shopping_cart_outlined, titulo: 'Tu carrito está vacío'),
      );
    }
    final direcciones = ref.watch(direccionesProvider);
    final textos = Theme.of(context).textTheme;
    final total = carrito.subtotal + (_cotizacion?.costoEnvio ?? 0) + (_cotizacion?.tarifaServicio ?? 0);
    final listo = _direccion != null && _cotizacion != null && !_cotizando;

    return Pantalla(
      titulo: 'Confirmar pedido',
      abajo: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: BotonPrincipal(
          texto: listo ? 'Hacer pedido · ${Formato.bs(total)}' : 'Hacer pedido',
          icono: Icons.check_circle_outline,
          cargando: _enviando,
          onPressed: listo ? () => _confirmar(carrito) : null,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          const TituloSeccion('¿Dónde lo recibes?', Icons.place_outlined),
          direcciones.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(AppEspacios.m), child: CircularProgressIndicator())),
            error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(direccionesProvider)),
            data: (lista) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lista.isEmpty)
                  Text('Agrega la dirección donde quieres recibir tu pedido.', style: textos.bodyMedium),
                RadioGroup<int>(
                  groupValue: _direccion?.id,
                  onChanged: (id) => _elegir(lista.firstWhere((d) => d.id == id)),
                  child: Column(
                    children: [
                      for (final d in lista)
                        Card(
                          child: RadioListTile<int>(
                            key: Key('direccion-${d.id}'),
                            value: d.id,
                            title: Text(d.titulo),
                            subtitle: Text([d.direccion, ?d.referencia].join(' · ')),
                          ),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('agregar-direccion'),
                    onPressed: () async {
                      final nueva = await mostrarNuevaDireccion(context);
                      if (nueva != null) _elegir(nueva);
                    },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Agregar dirección'),
                  ),
                ),
              ],
            ),
          ),
          if (_cotizando) const LinearProgressIndicator(),
          if (_errorEnvio != null) AvisoError(_errorEnvio!),
          const SizedBox(height: AppEspacios.m),
          const TituloSeccion('¿Cómo pagas?', Icons.payments_outlined),
          RadioGroup<String>(
            groupValue: _metodoPago,
            onChanged: (v) => setState(() => _metodoPago = v ?? 'efectivo'),
            child: const Column(
              children: [
                RadioListTile(value: 'efectivo', title: Text('Efectivo al recibir'), secondary: Icon(Icons.money)),
                RadioListTile(
                  value: 'qr',
                  title: Text('Pago con QR'),
                  subtitle: Text('El negocio te pasará su QR'),
                  secondary: Icon(Icons.qr_code_2),
                ),
                RadioListTile(
                  value: 'transferencia',
                  title: Text('Transferencia'),
                  subtitle: Text('El negocio te pasará su cuenta'),
                  secondary: Icon(Icons.account_balance_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppEspacios.s),
          TextField(
            controller: _notas,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Nota para el negocio (opcional)',
              hintText: 'Ej. tocar el timbre, llamar al llegar…',
              prefixIcon: Icon(Icons.chat_bubble_outline),
            ),
          ),
          const SizedBox(height: AppEspacios.s),
          const TituloSeccion('Resumen', Icons.receipt_long_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppEspacios.m),
              child: Column(
                children: [
                  _Fila('${carrito.negocio.nombre} · ${carrito.unidades} producto${carrito.unidades == 1 ? '' : 's'}',
                      Formato.bs(carrito.subtotal)),
                  _Fila(
                    _cotizacion == null ? 'Envío' : 'Envío (${_cotizacion!.distanciaKm.toStringAsFixed(1)} km)',
                    _cotizacion == null ? '—' : Formato.bs(_cotizacion!.costoEnvio),
                  ),
                  if ((_cotizacion?.tarifaServicio ?? 0) > 0) _Fila('Servicio', Formato.bs(_cotizacion!.tarifaServicio)),
                  const Divider(height: AppEspacios.l),
                  _Fila('Total', listo ? Formato.bs(total) : '—', fuerte: true),
                ],
              ),
            ),
          ),
          if (_errorGeneral != null) ...[const SizedBox(height: AppEspacios.m), AvisoError(_errorGeneral!)],
          const SizedBox(height: AppEspacios.xl),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.texto, this.valor, {this.fuerte = false});

  final String texto;
  final String valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = fuerte ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}
