import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/domain/pedido.dart';
import '../data/repartidor_repository.dart';

/// "Cobra Bs 245 en efectivo · Paga con Bs 300 · dale Bs 55 de cambio".
({String titulo, String? detalle}) textoCobro(Pedido p) {
  if (p.metodoPago != 'efectivo') return (titulo: 'Ya pagó con QR', detalle: 'No cobres nada');
  final titulo = 'Cobra ${Formato.bs(p.total)} en efectivo';
  final pagaCon = p.pagaCon;
  if (pagaCon == null) return (titulo: titulo, detalle: 'No dijo con cuánto paga: lleva cambio');
  final cambio = p.cambio ?? (pagaCon - p.total);
  if (cambio <= 0) return (titulo: titulo, detalle: 'Paga justo, sin cambio');
  return (titulo: titulo, detalle: 'Paga con ${Formato.bs(pagaCon)} · dale ${Formato.bs(cambio)} de cambio');
}

/// Pedido con bebidas alcohólicas: el repartidor pide el carnet antes de entregarlo.
class AvisoCarnet extends StatelessWidget {
  const AvisoCarnet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      key: const Key('aviso-carnet'),
      color: c.errorContainer,
      child: ListTile(
        leading: Icon(Icons.badge_outlined, color: c.onErrorContainer),
        title: Text(
          'Pide el carnet de identidad',
          style: TextStyle(color: c.onErrorContainer, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Lleva bebidas alcohólicas o tabaco: entrégalo solo a una persona mayor de 18 años. Si no muestra su carnet o es '
          'menor, no lo entregues y reporta el problema.',
          style: TextStyle(color: c.onErrorContainer),
        ),
      ),
    );
  }
}

/// Paso 2 · Entregar: cuánto cobrar (con el cambio) y el PIN de 4 números que
/// el cliente ve en su app, con un teclado grande y 4 casillas.
class EntregarPinScreen extends ConsumerStatefulWidget {
  const EntregarPinScreen({super.key});

  @override
  ConsumerState<EntregarPinScreen> createState() => _EntregarPinScreenState();
}

class _EntregarPinScreenState extends ConsumerState<EntregarPinScreen> {
  static const largo = 4;
  String _pin = '';
  String? _error;
  bool _enviando = false;

  void _tecla(String digito) {
    if (_enviando || _pin.length >= largo) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digito;
      _error = null;
    });
  }

  void _borrar() {
    if (_enviando || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _confirmar(Pedido p) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _enviando = true);
    try {
      await ref.read(repartidorRepositoryProvider).cambiarEstado(p.id, EstadoPedido.entregado, codigo: _pin);
    } on ApiException catch (e) {
      if (!mounted) return;
      final delPin = e.errorDe('codigo');
      setState(() {
        _enviando = false;
        // PIN equivocado: se borra y se vuelve a pedir, con el mensaje.
        _pin = '';
        _error = delPin ?? e.errorDe('estado') ?? e.mensaje;
      });
      if (delPin == null) ref.invalidate(pedidoActualProvider);
      return;
    }
    ref.invalidate(pedidoActualProvider);
    ref.invalidate(pedidosDisponiblesProvider);
    ref.invalidate(entregasProvider);
    ref.invalidate(gananciasProvider);
    if (!mounted) return;
    mensajero.showSnackBar(const SnackBar(content: Text('¡Pedido entregado! Lo verás en "Mis entregas".')));
    context.go('/inicio');
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoActualProvider);
    const titulo = 'Entregar';

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
          ? const Pantalla(
              titulo: titulo,
              child: EstadoVacio(icono: Icons.delivery_dining_outlined, titulo: 'No tienes un pedido en curso'),
            )
          : Pantalla(titulo: titulo, child: _contenido(p)),
    );
  }

  Widget _contenido(Pedido p) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final cobro = textoCobro(p);
    final efectivo = p.metodoPago == 'efectivo';

    return ListView(
      padding: const EdgeInsets.all(AppEspacios.m),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Paso 2 · Entregar', style: textos.labelLarge?.copyWith(color: c.primary)),
                Text('${p.clienteNombre ?? 'Cliente'} · ${p.direccionEntrega}', style: textos.titleMedium),
                const SizedBox(height: AppEspacios.m),
                Card(
                  key: const Key('cobro-entrega'),
                  color: efectivo ? c.tertiaryContainer : c.primaryContainer,
                  child: ListTile(
                    leading: Icon(
                      efectivo ? Icons.payments_outlined : Icons.qr_code_2,
                      color: efectivo ? c.onTertiaryContainer : c.onPrimaryContainer,
                    ),
                    title: Text(
                      cobro.titulo,
                      style: textos.titleMedium?.copyWith(
                        color: efectivo ? c.onTertiaryContainer : c.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: cobro.detalle == null
                        ? null
                        : Text(
                            cobro.detalle!,
                            style: TextStyle(color: efectivo ? c.onTertiaryContainer : c.onPrimaryContainer),
                          ),
                  ),
                ),
                if (p.soloMayores) ...[const SizedBox(height: AppEspacios.s), const AvisoCarnet()],
                const SizedBox(height: AppEspacios.l),
                Text('Pide el código al cliente', textAlign: TextAlign.center, style: textos.titleMedium),
                Text(
                  'Son 4 números que aparecen en su app',
                  textAlign: TextAlign.center,
                  style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: AppEspacios.m),
                Semantics(
                  label: 'Código: ${_pin.length} de $largo números',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < largo; i++)
                        Container(
                          key: Key('casilla-$i'),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 56,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _error != null ? c.error : (i == _pin.length ? c.primary : c.outlineVariant),
                              width: i == _pin.length || _error != null ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            i < _pin.length ? _pin[i] : '',
                            style: textos.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppEspacios.s),
                SizedBox(
                  height: 40,
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          key: const Key('mensaje-pin'),
                          textAlign: TextAlign.center,
                          style: textos.bodyMedium?.copyWith(color: c.error),
                        ),
                ),
                _Teclado(alTecla: _tecla, alBorrar: _borrar),
                const SizedBox(height: AppEspacios.m),
                BotonPrincipal(
                  key: const Key('confirmar-entrega'),
                  texto: 'Confirmar entrega',
                  icono: Icons.check_circle_outline,
                  cargando: _enviando,
                  onPressed: _pin.length == largo ? () => _confirmar(p) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Teclado numérico grande: 1–9, 0 y borrar.
class _Teclado extends StatelessWidget {
  const _Teclado({required this.alTecla, required this.alBorrar});

  final ValueChanged<String> alTecla;
  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    Widget tecla(String texto) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FilledButton.tonal(
          key: Key('tecla-$texto'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 60)),
          onPressed: () => alTecla(texto),
          child: Text(texto, style: textos.headlineSmall),
        ),
      ),
    );
    return Column(
      children: [
        for (final fila in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final t in fila) tecla(t)]),
        Row(
          children: [
            const Spacer(),
            tecla('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  key: const Key('tecla-borrar'),
                  tooltip: 'Borrar',
                  style: IconButton.styleFrom(minimumSize: const Size(0, 60)),
                  onPressed: alBorrar,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
