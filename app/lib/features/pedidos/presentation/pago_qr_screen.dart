import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';

/// Cobro con QR SIMULADO: no se cobra dinero real, pero sigue los pasos de un
/// cobro de verdad.
///
/// - Muestra el QR del pedido. Ese QR lleva a la "pasarela" de prueba del
///   servidor: si se escanea con otro celular y se toca "Pagar", el cobro se procesa.
/// - Aquí también se puede tocar "Simular pago".
/// - Mientras tanto, consulta el pedido cada pocos segundos. Cuando el cobro
///   se procesa, avisa "Cobro realizado" y vuelve al pedido, que sigue su
///   curso: el negocio ya puede aceptarlo.
class PagoQrScreen extends ConsumerStatefulWidget {
  const PagoQrScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  ConsumerState<PagoQrScreen> createState() => _PagoQrScreenState();
}

class _PagoQrScreenState extends ConsumerState<PagoQrScreen> {
  Timer? _reloj;
  bool _pagando = false;
  bool _cobrado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // ¿Ya lo pagaron escaneando el QR? Se revisa cada 3 segundos.
    _reloj = Timer.periodic(const Duration(seconds: 3), (_) => ref.invalidate(pedidoProvider(widget.pedidoId)));
    ref.listenManual(pedidoProvider(widget.pedidoId), (_, siguiente) {
      if (siguiente.value?.estadoPago == 'pagado') _cobroRealizado();
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _simularPago() async {
    setState(() {
      _pagando = true;
      _error = null;
    });
    try {
      await ref.read(pedidosRepositoryProvider).pagarQr(widget.pedidoId);
      _cobroRealizado();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errorDe('pago') ?? e.mensaje);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  /// Llega una sola vez, sea por el botón o porque escanearon el QR.
  void _cobroRealizado() {
    if (_cobrado || !mounted) return;
    _reloj?.cancel();
    setState(() => _cobrado = true);
    ref.invalidate(pedidoProvider(widget.pedidoId));
    ref.invalidate(misPedidosProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cobro realizado. El negocio ya puede aceptar tu pedido.')),
    );
  }

  void _volverAlPedido() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/pedido/${widget.pedidoId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoProvider(widget.pedidoId));

    return Pantalla(
      titulo: 'Pagar con QR',
      child: pedido.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(pedidoProvider(widget.pedidoId))),
        data: (p) => ListView(
          padding: const EdgeInsets.all(AppEspacios.m),
          children: [
            if (_cobrado || p.estadoPago == 'pagado')
              _Cobrado(pedido: p, alContinuar: _volverAlPedido)
            else if (p.estado.fallido || p.pagoQr == null)
              EstadoVacio(
                icono: Icons.block,
                titulo: p.estado.fallido ? 'Este pedido fue cancelado' : 'Este pedido no se paga con QR',
              )
            else
              ..._porPagar(p),
          ],
        ),
      ),
    );
  }

  List<Widget> _porPagar(Pedido p) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return [
      Text('Paga ${Formato.bs(p.total)}', textAlign: TextAlign.center, style: textos.headlineSmall),
      Text('a ${p.negocioNombre} · Pedido #${p.id}', textAlign: TextAlign.center, style: textos.bodyMedium),
      const SizedBox(height: AppEspacios.s),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppEspacios.s, vertical: 4),
          decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
          child: Text('Pago de prueba: no se cobra dinero real',
              style: textos.labelMedium?.copyWith(color: c.onTertiaryContainer)),
        ),
      ),
      const SizedBox(height: AppEspacios.m),
      Center(
        // Fondo blanco siempre (también en modo oscuro): así cualquier cámara lo lee.
        child: Container(
          padding: const EdgeInsets.all(AppEspacios.s),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: QrImageView(
            key: const Key('qr-pago'),
            data: p.pagoQr!,
            size: 220,
            backgroundColor: Colors.white,
            semanticsLabel: 'Código QR para pagar el pedido ${p.id}',
          ),
        ),
      ),
      const SizedBox(height: AppEspacios.m),
      Text(
        'Escanéalo con la cámara de otro celular para pagar, o toca «Simular pago».',
        textAlign: TextAlign.center,
        style: textos.bodyMedium,
      ),
      const SizedBox(height: AppEspacios.s),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppEspacios.s),
          Flexible(child: Text('Esperando la confirmación del pago…', style: textos.bodySmall)),
        ],
      ),
      if (_error != null) ...[const SizedBox(height: AppEspacios.m), AvisoError(_error!)],
      const SizedBox(height: AppEspacios.l),
      BotonPrincipal(
        key: const Key('simular-pago'),
        texto: 'Simular pago',
        icono: Icons.qr_code_scanner,
        cargando: _pagando,
        onPressed: _simularPago,
      ),
      const SizedBox(height: AppEspacios.s),
      TextButton(onPressed: _volverAlPedido, child: const Text('Pagar después')),
    ];
  }
}

class _Cobrado extends StatelessWidget {
  const _Cobrado({required this.pedido, required this.alContinuar});

  final Pedido pedido;
  final VoidCallback alContinuar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      key: const Key('cobro-realizado'),
      children: [
        const SizedBox(height: AppEspacios.xl),
        Icon(Icons.check_circle_rounded, size: 96, color: c.primary)
            .animate()
            .scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: AppEspacios.m),
        Text('Cobro realizado', style: textos.headlineSmall),
        const SizedBox(height: AppEspacios.xs),
        Text('${Formato.bs(pedido.total)} a ${pedido.negocioNombre}', style: textos.bodyLarge),
        const SizedBox(height: AppEspacios.s),
        Text('Te avisaremos cuando el negocio acepte tu pedido.', textAlign: TextAlign.center, style: textos.bodyMedium),
        const SizedBox(height: AppEspacios.l),
        BotonPrincipal(texto: 'Ver mi pedido', icono: Icons.receipt_long_outlined, onPressed: alContinuar),
      ],
    );
  }
}
