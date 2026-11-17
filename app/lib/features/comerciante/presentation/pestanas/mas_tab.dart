import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../auth/domain/usuario.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/mi_negocio_repository.dart';
import '../../domain/documento_subido.dart';
import '../../domain/horario.dart';
import '../../domain/negocio.dart';

/// "Más": el aviso de las entregas, perfil, horario, calificaciones, compras
/// y gastos, documentos, cambiar a la vista cliente y cerrar sesión.
class MasTab extends ConsumerWidget {
  const MasTab({super.key, required this.negocio});

  final Negocio negocio;

  /// "Lun a sáb · 08:00 a 22:00" (el horario que más se repite).
  static String resumenHorario(List<Horario> horarios) {
    if (horarios.isEmpty) return 'Todavía no cargaste tu horario';
    String hora(String h) => h.length >= 5 ? h.substring(0, 5) : h;
    final porTramo = <String, List<int>>{};
    for (final h in horarios) {
      porTramo.putIfAbsent('${hora(h.apertura)} a ${hora(h.cierre)}', () => []).add(h.diaSemana);
    }
    final principal = porTramo.entries.reduce((a, b) => b.value.length > a.value.length ? b : a);
    final dias = principal.value.toSet().toList()..sort();
    const cortos = ['Lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    String nombre(int d, {bool primero = false}) {
      final n = cortos[d - 1];
      return primero ? '${n[0].toUpperCase()}${n.substring(1)}' : n;
    }

    final seguidos = dias.length > 2 && dias.last - dias.first == dias.length - 1;
    final textoDias = dias.length == 7
        ? 'Todos los días'
        : seguidos
        ? '${nombre(dias.first, primero: true)} a ${nombre(dias.last)}'
        : [for (final (i, d) in dias.indexed) nombre(d, primero: i == 0)].join(', ');
    return '$textoDias · ${principal.key}${porTramo.length > 1 ? ' (y otros horarios)' : ''}';
  }

  /// "NIT y licencia verificados", "1 en revisión"…
  static ({String texto, bool listo}) resumenDocumentos(List<DocumentoSubido> documentos) {
    if (documentos.isEmpty) return (texto: 'Sube los documentos de tu negocio', listo: false);
    final rechazados = documentos.where((d) => d.rechazado).length;
    final pendientes = documentos.where((d) => !d.aprobado && !d.rechazado).length;
    if (rechazados > 0) {
      return (texto: rechazados == 1 ? '1 rechazado: revísalo' : '$rechazados rechazados: revísalos', listo: false);
    }
    if (pendientes > 0) return (texto: pendientes == 1 ? '1 en revisión' : '$pendientes en revisión', listo: false);
    return (texto: 'Todos verificados', listo: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final documentos = ref.watch(documentosNegocioProvider).value;
    final estadoDocs = documentos == null ? null : resumenDocumentos(documentos);

    Future<void> aCliente() async {
      try {
        await ref.read(authControllerProvider.notifier).cambiarVista(Vista.cliente);
      } on ApiException catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }

    final opciones = [
      (
        Icons.storefront_outlined,
        'Perfil de la tienda',
        'Logo, nombre, ubicación y descripción',
        '/negocio/perfil',
        null,
      ),
      (Icons.schedule, 'Horario', resumenHorario(negocio.horarios), '/negocio/horario', null),
      (
        Icons.star_outline_rounded,
        'Calificaciones',
        negocio.totalResenas == 0
            ? 'Todavía no tienes opiniones'
            : '★ ${negocio.ratingPromedio?.toStringAsFixed(1)} · '
                  '${negocio.totalResenas} ${negocio.totalResenas == 1 ? 'opinión' : 'opiniones'}',
        '/negocio/calificaciones',
        null,
      ),
      (
        Icons.receipt_long_outlined,
        'Compras y gastos',
        'Anota lo que compras para tu negocio',
        '/negocio/registros',
        null,
      ),
      (
        Icons.badge_outlined,
        'Documentos',
        estadoDocs?.texto ?? 'NIT, licencia y tu carnet',
        '/negocio/documentos',
        estadoDocs?.listo == true ? Icon(Icons.verified, color: c.primary) : null,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppEspacios.m),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  key: const Key('aviso-entregas'),
                  color: c.secondaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.delivery_dining_outlined, color: c.onSecondaryContainer),
                    title: Text(
                      'Las entregas las hace un repartidor de MDR Market.',
                      style: TextStyle(color: c.onSecondaryContainer, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Tú solo alistas el pedido y lo marcas como listo; nosotros buscamos al repartidor.',
                      style: TextStyle(color: c.onSecondaryContainer),
                    ),
                  ),
                ),
                const SizedBox(height: AppEspacios.m),
                for (final (icono, titulo, subtitulo, ruta, marca) in opciones)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppEspacios.s),
                    child: ListTile(
                      key: Key('mas-$ruta'),
                      leading: Icon(icono, color: c.primary),
                      title: Text(titulo),
                      subtitle: Text(subtitulo),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [?marca, const Icon(Icons.chevron_right)],
                      ),
                      onTap: () => context.push(ruta),
                    ),
                  ),
                const SizedBox(height: AppEspacios.m),
                OutlinedButton.icon(
                  key: const Key('a-vista-cliente'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: aCliente,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Cambiar a vista cliente'),
                ),
                const SizedBox(height: AppEspacios.s),
                TextButton.icon(
                  key: const Key('cerrar-sesion-comercio'),
                  style: TextButton.styleFrom(foregroundColor: c.error, minimumSize: const Size.fromHeight(48)),
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
