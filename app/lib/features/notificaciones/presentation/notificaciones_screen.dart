import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/notificaciones_repository.dart';
import '../domain/notificacion.dart';

/// Avisos del usuario. Tocar uno lo marca como leído y abre su pedido (si tiene).
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avisos = ref.watch(notificacionesProvider);
    final hayNoLeidas = (avisos.value?.noLeidas ?? 0) > 0;

    return Pantalla(
      titulo: 'Notificaciones',
      acciones: [
        if (hayNoLeidas)
          TextButton(
            key: const Key('leer-todas'),
            onPressed: () async {
              try {
                await ref.read(notificacionesRepositoryProvider).leerTodas();
              } on ApiException catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
              }
              ref.invalidate(notificacionesProvider);
            },
            child: const Text('Marcar todas'),
          ),
      ],
      child: avisos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(notificacionesProvider)),
        data: (datos) => datos.items.isEmpty
            ? const EstadoVacio(
                icono: Icons.notifications_none_rounded,
                titulo: 'No tienes notificaciones',
                texto: 'Aquí te avisamos cómo van tus pedidos.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(notificacionesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppEspacios.s),
                  itemCount: datos.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => Aparecer(
                    orden: i.clamp(0, 8),
                    child: _Fila(aviso: datos.items[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.aviso});

  final Notificacion aviso;

  IconData get _icono => switch (aviso.tipo) {
    final t when t.startsWith('pedido_en_camino') => Icons.delivery_dining_outlined,
    final t when t.contains('entregado') => Icons.check_circle_outline,
    final t when t.contains('cancelado') || t.contains('rechazado') => Icons.cancel_outlined,
    final t when t.startsWith('pago') => Icons.qr_code_2,
    final t when t.startsWith('reporte') => Icons.flag_outlined,
    _ => Icons.notifications_none_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return ListTile(
      key: Key('aviso-${aviso.id}'),
      tileColor: aviso.leida ? null : c.secondaryContainer.withValues(alpha: 0.5),
      leading: CircleAvatar(
        backgroundColor: c.secondaryContainer,
        child: Icon(_icono, color: c.primary),
      ),
      title: Text(aviso.titulo, style: TextStyle(fontWeight: aviso.leida ? FontWeight.w500 : FontWeight.w800)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aviso.cuerpo != null) Text(aviso.cuerpo!),
          Text(Formato.hace(aviso.fecha), style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
      trailing: aviso.leida ? null : Icon(Icons.circle, size: 10, color: c.primary, semanticLabel: 'Sin leer'),
      onTap: () async {
        if (!aviso.leida) {
          try {
            await ref.read(notificacionesRepositoryProvider).leer(aviso.id);
          } on ApiException {
            // Si no se pudo marcar, igual se abre.
          }
          ref.invalidate(notificacionesProvider);
        }
        if (aviso.pedidoId != null && context.mounted) context.push('/pedido/${aviso.pedidoId}');
      },
    );
  }
}
