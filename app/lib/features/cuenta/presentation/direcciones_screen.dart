import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/data/pedidos_repository.dart';
import '../../pedidos/domain/direccion.dart';
import '../../pedidos/presentation/direccion_sheet.dart';

/// "Mis direcciones": dónde recibe por defecto (se usa en el Inicio para el
/// envío y el tiempo), agregar una nueva y borrar las que ya no usa.
class DireccionesScreen extends ConsumerWidget {
  const DireccionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direcciones = ref.watch(direccionesProvider);
    final entrega = ref.watch(entregaClienteProvider).value;

    return Pantalla(
      titulo: 'Mis direcciones',
      abajo: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: BotonPrincipal(
          key: const Key('agregar-direccion'),
          texto: 'Agregar dirección',
          icono: Icons.add_location_alt_outlined,
          onPressed: () async {
            if (await mostrarNuevaDireccion(context) != null) ref.invalidate(direccionesProvider);
          },
        ),
      ),
      child: direcciones.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(direccionesProvider)),
        data: (lista) => lista.isEmpty
            ? const EstadoVacio(
                icono: Icons.place_outlined,
                titulo: 'Todavía no guardaste direcciones',
                texto: 'Agrega dónde recibes tus pedidos para ver el envío y el tiempo de cada tienda.',
              )
            : ListView(
                padding: const EdgeInsets.all(AppEspacios.m),
                children: [
                  for (final (i, d) in lista.indexed)
                    Aparecer(
                      orden: i,
                      child: _Fila(direccion: d, elegida: d.id == entrega?.id),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.direccion, required this.elegida});

  final Direccion direccion;
  final bool elegida;

  IconData get _icono => switch (direccion.etiqueta) {
    'Casa' => Icons.home_outlined,
    'Trabajo' => Icons.work_outline,
    _ => Icons.place_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final repo = ref.read(pedidosRepositoryProvider);

    Future<void> hacer(Future<void> Function() accion) async {
      try {
        await accion();
        ref.invalidate(direccionesProvider);
      } on ApiException catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }

    return Card(
      color: elegida ? c.secondaryContainer : null,
      child: ListTile(
        key: Key('direccion-${direccion.id}'),
        leading: Icon(_icono, color: c.primary),
        title: Text(direccion.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (direccion.titulo != direccion.direccion) direccion.direccion,
            if (direccion.referencia?.isNotEmpty ?? false) direccion.referencia!,
            if (elegida) 'Aquí recibes tus pedidos',
          ].join(' · '),
        ),
        // Tocarla: pasa a ser donde recibe.
        onTap: elegida
            ? null
            : () => hacer(
                () => repo.guardarDireccion(
                  id: direccion.id,
                  etiqueta: direccion.etiqueta,
                  direccion: direccion.direccion,
                  referencia: direccion.referencia,
                  ubicacion: direccion.ubicacion,
                  predeterminada: true,
                ),
              ),
        trailing: IconButton(
          key: Key('borrar-direccion-${direccion.id}'),
          tooltip: 'Borrar',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final si = await showDialog<bool>(
              context: context,
              builder: (contexto) => AlertDialog(
                title: const Text('¿Borrar esta dirección?'),
                content: Text(direccion.direccion),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Sí, borrar')),
                ],
              ),
            );
            if (si == true) await hacer(() => repo.borrarDireccion(direccion.id));
          },
        ),
      ),
    );
  }
}
