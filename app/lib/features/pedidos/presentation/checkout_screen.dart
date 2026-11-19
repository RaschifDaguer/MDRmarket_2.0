import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../carrito/domain/carrito.dart';
import '../../carrito/presentation/carrito_controller.dart';
import '../../catalogo/data/catalogo_repository.dart';
import '../../catalogo/domain/tienda.dart';
import '../../catalogo/presentation/widgets/tarjetas_catalogo.dart';
import '../data/pedidos_repository.dart';
import '../domain/direccion.dart';
import 'direccion_sheet.dart';

/// Último paso: dónde entregar, cómo pagar (en efectivo, con cuánto, para el
/// cambio), cuándo llega y confirmar el pedido.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notas = TextEditingController();
  final _pagaCon = TextEditingController();
  Direccion? _direccion;

  /// Tiempo estimado hasta la dirección elegida (la API lo calcula).
  EnvioTienda? _llegada;
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
    _pagaCon.dispose();
    super.dispose();
  }

  Future<void> _elegir(Direccion direccion) async {
    final carrito = ref.read(carritoProvider);
    if (carrito == null) return;
    setState(() {
      _direccion = direccion;
      _cotizacion = null;
      _llegada = null;
      _errorEnvio = null;
      _cotizando = true;
    });
    // El tiempo de llegada no es imprescindible: si falla, no se muestra.
    ref.read(catalogoRepositoryProvider).tienda(carrito.negocio.id, ubicacion: direccion.ubicacion).then((t) {
      if (mounted && _direccion == direccion) setState(() => _llegada = t.tienda.envio);
    }, onError: (_) {});
    try {
      final cotizacion = await ref
          .read(pedidosRepositoryProvider)
          .cotizar(carrito.negocio.id, direccion.ubicacion, carrito.items.map((i) => i.producto.id).toList());
      if (mounted && _direccion == direccion) setState(() => _cotizacion = cotizacion);
    } on ApiException catch (e) {
      if (mounted && _direccion == direccion) {
        setState(() => _errorEnvio = e.errorDe('latitud') ?? e.errorDe('negocio_id') ?? e.mensaje);
      }
    } finally {
      if (mounted && _direccion == direccion) setState(() => _cotizando = false);
    }
  }

  /// Bebidas alcohólicas o tabaco: antes de pedir, dos mensajes. 1) ¿Es mayor
  /// de edad? 2) Acepta comprarlos bajo su responsabilidad (la API exige los dos).
  Future<bool> _confirmarMayorDeEdad() => confirmarEnDosPasos(
    context,
    icono: Icons.no_drinks_outlined,
    pregunta: '¿Usted es mayor de edad?',
    explicacion:
        'Su pedido tiene productos solo para mayores de 18 años (bebidas alcohólicas o tabaco). '
        'VENTA PROHIBIDA A MENORES DE 18 AÑOS.\n\n¿Es usted mayor de 18 años?',
    textoSi: 'Sí, soy mayor de 18',
    textoNo: 'No',
    siDiceNo:
        'No puede pedir bebidas alcohólicas ni tabaco: la venta a menores de 18 años está prohibida. '
        'Quítelos del carrito para hacer su pedido.',
    tituloDeclaracion: 'Confirme su compra',
    resumen:
        'Usted está de acuerdo en realizar la compra de estos productos, consciente de que marcó '
        '«Sí, soy mayor de 18». El repartidor le pedirá su carnet al entregar: si no lo muestra o es menor '
        'de edad, no entregará el pedido.',
    declaracion:
        'Declaro bajo mi responsabilidad que soy mayor de 18 años, que la información que di es verdadera '
        'y que la compra es para un adulto.',
    textoConfirmar: 'Confirmar compra',
  );

  Future<void> _confirmar(Carrito carrito) async {
    if (carrito.soloMayores && !await _confirmarMayorDeEdad()) return;
    if (!mounted) return;
    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });
    final router = GoRouter.of(context);
    try {
      final pedido = await ref
          .read(pedidosRepositoryProvider)
          .crear(
            carrito,
            (direccionId: _direccion!.id, direccion: null, referencia: null, ubicacion: null),
            metodoPago: _metodoPago,
            notas: _notas.text,
            pagaCon: _metodoPago == 'efectivo' ? _pagaConValor : null,
            confirmaMayorEdad: carrito.soloMayores,
          );
      ref.read(carritoProvider.notifier).vaciar();
      ref.invalidate(misPedidosProvider);
      router.go('/inicio');
      if (_metodoPago == 'qr') {
        // Con QR se paga ahora: el negocio lo acepta recién cuando está pagado.
        router.push('/pedido/${pedido.id}');
        router.push('/pedido/${pedido.id}/pagar-qr');
      } else {
        router.push('/pedido/${pedido.id}/enviado');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        // El primer error que mande la API (stock, mínimo, cobertura…) o el mensaje general.
        _errorGeneral = e.errores.values.firstOrNull?.firstOrNull ?? e.mensaje;
      });
    }
  }

  /// Lo que escribió en "¿Con cuánto pagas?" (null si nada o no es un número).
  double? get _pagaConValor => double.tryParse(_pagaCon.text.trim().replaceAll(',', '.'));

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
    final pagaCon = _pagaConValor;
    final faltaParaElTotal = _metodoPago == 'efectivo' && pagaCon != null && pagaCon < total;
    final listo = _direccion != null && _cotizacion != null && !_cotizando && !faltaParaElTotal;
    final ahorro = carrito.items.fold<double>(
      0,
      (t, i) => t + (i.producto.precio - i.producto.precioFinal) * i.cantidad,
    );

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
          if (carrito.soloMayores) ...[const AvisoSoloMayores(), const SizedBox(height: AppEspacios.m)],
          const TituloSeccion('¿Dónde lo recibes?', Icons.place_outlined),
          direcciones.when(
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(AppEspacios.m), child: CircularProgressIndicator()),
            ),
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
            // Solo efectivo o QR (el cobro con QR es de prueba: no mueve dinero real).
            child: const Column(
              children: [
                RadioListTile(
                  key: Key('pago-efectivo'),
                  value: 'efectivo',
                  title: Text('Efectivo al recibir'),
                  secondary: Icon(Icons.money),
                ),
                RadioListTile(
                  key: Key('pago-qr'),
                  value: 'qr',
                  title: Text('Pago con QR'),
                  subtitle: Text('Al confirmar te mostramos el QR para pagar'),
                  secondary: Icon(Icons.qr_code_2),
                ),
              ],
            ),
          ),
          // Efectivo: con cuánto paga, para que el repartidor lleve cambio (opcional).
          if (_metodoPago == 'efectivo') ...[
            TextField(
              key: const Key('campo-paga-con'),
              controller: _pagaCon,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '¿Con cuánto pagas? (para tu cambio)',
                prefixText: 'Bs ',
                errorText: faltaParaElTotal && _cotizacion != null
                    ? 'Tiene que ser al menos ${Formato.bs(total)}'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (pagaCon != null && !faltaParaElTotal && _cotizacion != null)
              Padding(
                padding: const EdgeInsets.only(top: AppEspacios.xs, left: AppEspacios.s),
                child: Text(
                  pagaCon == total
                      ? 'Pagas justo, sin cambio.'
                      : 'El repartidor te dará ${Formato.bs(pagaCon - total)} de cambio.',
                  key: const Key('texto-cambio'),
                  style: textos.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: AppEspacios.m),
          ],
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
                  _Fila(
                    '${carrito.negocio.nombre} · ${carrito.unidades} producto${carrito.unidades == 1 ? '' : 's'}',
                    Formato.bs(carrito.subtotal),
                  ),
                  _Fila(
                    _cotizacion == null ? 'Envío' : 'Envío (${_cotizacion!.distanciaKm.toStringAsFixed(1)} km)',
                    _cotizacion == null ? '—' : Formato.bs(_cotizacion!.costoEnvio),
                  ),
                  if ((_cotizacion?.tarifaServicio ?? 0) > 0)
                    _Fila('Servicio', Formato.bs(_cotizacion!.tarifaServicio)),
                  if (ahorro > 0) _Fila('Ahorras con ofertas', '−${Formato.bs(ahorro)}', clave: 'ahorro-checkout'),
                  const Divider(height: AppEspacios.l),
                  _Fila('Total', _cotizacion != null ? Formato.bs(total) : '—', fuerte: true),
                  if (_llegada?.tiempoMin case final minimo?)
                    Padding(
                      padding: const EdgeInsets.only(top: AppEspacios.s),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: AppEspacios.xs),
                          Flexible(
                            child: Text(
                              'Llega entre ${_hora(minimo)} y ${_hora(_llegada!.tiempoMax ?? minimo)}',
                              key: const Key('llega-entre'),
                              style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// "14:20": la hora dentro de [minutos].
String _hora(int minutos) {
  final h = DateTime.now().add(Duration(minutes: minutos));
  return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
}

class _Fila extends StatelessWidget {
  const _Fila(this.texto, this.valor, {this.fuerte = false, this.clave});

  final String texto;
  final String valor;
  final bool fuerte;
  final String? clave;

  @override
  Widget build(BuildContext context) {
    final estilo = fuerte ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      key: clave == null ? null : Key(clave!),
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
