import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';

/// Después de hacer un pedido (en efectivo): ya se envió a la tienda, que
/// tiene que aceptarlo. Muestra el PIN de entrega y lleva a seguirlo.
class PedidoEnviadoScreen extends ConsumerWidget {
  const PedidoEnviadoScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedido = ref.watch(pedidoProvider(pedidoId));

    return Scaffold(
      body: SafeArea(
        child: pedido.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(pedidoProvider(pedidoId))),
          data: (p) => _Contenido(pedido: p),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final animar = AppMovimiento.activo(context);
    Widget check = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, size: 56, color: c.onPrimary),
    );
    if (animar) {
      check = check.animate().scale(
        begin: const Offset(0.4, 0.4),
        duration: AppMovimiento.lento,
        curve: Curves.elasticOut,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(AppEspacios.l),
          shrinkWrap: true,
          children: [
            Center(child: check),
            const SizedBox(height: AppEspacios.l),
            Aparecer(
              orden: 1,
              child: Text(
                '¡Pedido enviado!',
                key: const Key('titulo-enviado'),
                textAlign: TextAlign.center,
                style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppEspacios.s),
            Aparecer(
              orden: 2,
              child: Text(
                'Esperando que ${pedido.negocioNombre} lo acepte. Cuando lo tenga listo, '
                'buscamos un repartidor cerca.',
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant),
              ),
            ),
            if (pedido.codigoEntrega case final pin?) ...[
              const SizedBox(height: AppEspacios.l),
              Aparecer(
                orden: 3,
                child: Container(
                  padding: const EdgeInsets.all(AppEspacios.m),
                  decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Text('Tu código de entrega', style: textos.titleSmall),
                      const SizedBox(height: AppEspacios.s),
                      Row(
                        key: const Key('pin-enviado'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final digito in pin.split(''))
                            Container(
                              width: 48,
                              height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                digito,
                                style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: c.primary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppEspacios.s),
                      Text(
                        'Dáselo al repartidor solo cuando tengas tu pedido en la mano.',
                        textAlign: TextAlign.center,
                        style: textos.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppEspacios.m),
            Aparecer(
              orden: 4,
              child: Text(
                [
                  'Pedido #${pedido.id} · ${Formato.bs(pedido.total)}',
                  if (pedido.cambio case final cambio? when cambio > 0) 'Cambio: ${Formato.bs(cambio)}',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppEspacios.l),
            BotonPrincipal(
              key: const Key('seguir-pedido'),
              texto: 'Seguir mi pedido',
              icono: Icons.delivery_dining_outlined,
              onPressed: () => context.pushReplacement('/pedido/${pedido.id}'),
            ),
            const SizedBox(height: AppEspacios.s),
            TextButton(onPressed: () => context.go('/inicio'), child: const Text('Volver al inicio')),
          ],
        ),
      ),
    );
  }
}
