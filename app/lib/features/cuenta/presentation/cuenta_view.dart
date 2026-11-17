import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notificaciones/data/notificaciones_repository.dart';
import '../../pedidos/data/pedidos_repository.dart';

/// Pestaña "Cuenta" del cliente: sus datos, números, vistas (comercio y
/// repartidor), direcciones, notificaciones, tema, ayuda y cerrar sesión.
class CuentaView extends ConsumerWidget {
  const CuentaView({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final pedidos = ref.watch(misPedidosProvider).value;
    final direcciones = ref.watch(direccionesProvider).value;
    final noLeidas = ref.watch(notificacionesProvider).value?.noLeidas ?? 0;
    final iniciales = [
      usuario.nombre,
      usuario.apellido ?? '',
    ].where((p) => p.isNotEmpty).map((p) => p.characters.first.toUpperCase()).join();

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppEspacios.m),
            children: [
              Text('Mi cuenta', style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppEspacios.m),
              Aparecer(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: c.primary,
                      child: Text(
                        iniciales,
                        style: textos.titleLarge?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: AppEspacios.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            usuario.nombreCompleto,
                            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(usuario.email, style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppEspacios.m),
              Aparecer(
                orden: 1,
                child: Row(
                  children: [
                    _Numero(
                      clave: 'numero-pedidos',
                      valor: '${pedidos?.total ?? pedidos?.items.length ?? '–'}',
                      texto: 'Pedidos',
                    ),
                    const SizedBox(width: AppEspacios.s),
                    _Numero(clave: 'numero-direcciones', valor: '${direcciones?.length ?? '–'}', texto: 'Direcciones'),
                  ],
                ),
              ),
              const SizedBox(height: AppEspacios.l),
              _Titulo('Tus vistas'),
              _Vistas(usuario: usuario),
              const SizedBox(height: AppEspacios.l),
              _Titulo('Ajustes'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('cuenta-direcciones'),
                      leading: const Icon(Icons.place_outlined),
                      title: const Text('Mis direcciones'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/direcciones'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('cuenta-notificaciones'),
                      leading: const Icon(Icons.notifications_none_rounded),
                      title: const Text('Notificaciones'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (noLeidas > 0) Badge(label: Text('$noLeidas')),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => context.push('/notificaciones'),
                    ),
                    const Divider(height: 1),
                    const SelectorTema(),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('cuenta-ayuda'),
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Ayuda'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _ayuda(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppEspacios.m),
              OutlinedButton.icon(
                key: const Key('cerrar-sesion'),
                style: OutlinedButton.styleFrom(foregroundColor: c.error, minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              const SizedBox(height: AppEspacios.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _ayuda(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Ayuda'),
        content: const Text(
          '• Para seguir un pedido, ábrelo en la pestaña Pedidos.\n'
          '• Si algo salió mal con un pedido entregado, ábrelo y toca «Hubo un problema»: '
          'el equipo de MDR Market lo revisa y te responde en tus notificaciones.\n'
          '• Puedes cancelar un pedido mientras la tienda no lo acepte.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Entendido'))],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppEspacios.s, left: 4),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
  );
}

/// Un número grande con su texto ("14 Pedidos").
class _Numero extends StatelessWidget {
  const _Numero({required this.clave, required this.valor, required this.texto});

  final String clave;
  final String valor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        key: Key(clave),
        padding: const EdgeInsets.all(AppEspacios.m - 4),
        decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(
              valor,
              style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: c.onSecondaryContainer),
            ),
            Text(texto, style: textos.bodySmall?.copyWith(color: c.onSecondaryContainer)),
          ],
        ),
      ),
    );
  }
}

/// Cliente (ahora), Mi comercio y Quiero repartir: cambia de vista o invita a registrarse.
class _Vistas extends ConsumerWidget {
  const _Vistas({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tieneComercio = usuario.vistas.contains(Vista.comerciante);
    final tieneReparto = usuario.vistas.contains(Vista.repartidor);
    final rechazado = usuario.estadoRepartidor == 'rechazado';

    Future<void> cambiar(Vista vista) async {
      try {
        await ref.read(authControllerProvider.notifier).cambiarVista(vista);
      } on ApiException catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }

    return Card(
      child: Column(
        children: [
          const ListTile(leading: Icon(Icons.shopping_bag_outlined), title: Text('Cliente'), trailing: Text('(ahora)')),
          const Divider(height: 1),
          ListTile(
            key: const Key('vista-comercio'),
            leading: const Icon(Icons.storefront_outlined),
            title: Text(tieneComercio ? 'Mi comercio' : '¿Tienes un negocio?'),
            subtitle: tieneComercio ? null : const Text('Vende en MDR Market con tu misma cuenta'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => tieneComercio ? cambiar(Vista.comerciante) : context.go('/registrar-negocio'),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('vista-reparto'),
            leading: const Icon(Icons.delivery_dining_outlined),
            title: Text(tieneReparto ? 'Repartir' : 'Quiero repartir'),
            subtitle: tieneReparto
                ? null
                : Text(rechazado ? 'Tu solicitud no fue aprobada: mira el motivo' : 'Gana dinero llevando pedidos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => tieneReparto ? cambiar(Vista.repartidor) : context.go('/registrar-repartidor'),
          ),
        ],
      ),
    );
  }
}
