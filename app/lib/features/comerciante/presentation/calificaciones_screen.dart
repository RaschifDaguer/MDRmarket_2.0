import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/pagina.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../catalogo/domain/resena.dart';
import '../../catalogo/presentation/widgets/tarjeta_resena.dart';
import '../data/mi_negocio_repository.dart';
import '../domain/finanzas.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';

final _resenasProvider = FutureProvider.family<({Calificaciones resumen, Pagina<Resena> resenas}), int>(
  (ref, negocioId) => ref.watch(miNegocioRepositoryProvider).resenas(negocioId),
);

/// Reseñas del negocio y de sus productos, con el resumen de estrellas y
/// la opción de responder.
class CalificacionesScreen extends StatelessWidget {
  const CalificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ConNegocio(titulo: 'Calificaciones', builder: (negocio) => _Calificaciones(negocio: negocio));
}

class _Calificaciones extends ConsumerWidget {
  const _Calificaciones({required this.negocio});

  final Negocio negocio;

  Future<void> _responder(BuildContext context, WidgetRef ref, Resena resena) async {
    final control = TextEditingController(text: resena.respuesta);
    final respuesta = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Responder a ${resena.autor}'),
        content: TextField(
          controller: control,
          autofocus: true,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej. ¡Gracias por tu compra! Te esperamos pronto.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, control.text.trim()), child: const Text('Publicar')),
        ],
      ),
    );
    control.dispose();
    if (respuesta == null) return;
    try {
      await ref.read(miNegocioRepositoryProvider).responder(negocio.id, resena.id, respuesta);
      ref.invalidate(_resenasProvider(negocio.id));
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(_resenasProvider(negocio.id));
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Pantalla(
      titulo: 'Calificaciones',
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(_resenasProvider(negocio.id).future),
        child: datos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [VistaError(error: e, alReintentar: () => ref.invalidate(_resenasProvider(negocio.id)))]),
          data: (d) => ListView(
            padding: const EdgeInsets.all(AppEspacios.m),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacios.m),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Text(d.resumen.rating?.toStringAsFixed(1) ?? '—', style: textos.displaySmall),
                          EstrellasFijas((d.resumen.rating ?? 0).round()),
                          Text('${d.resumen.total} ${d.resumen.total == 1 ? 'reseña' : 'reseñas'}',
                              style: textos.bodySmall),
                        ],
                      ),
                      const SizedBox(width: AppEspacios.l),
                      Expanded(
                        child: Column(
                          children: [
                            for (var e = 5; e >= 1; e--)
                              Row(
                                children: [
                                  SizedBox(width: 14, child: Text('$e', style: textos.bodySmall)),
                                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A524)),
                                  const SizedBox(width: AppEspacios.xs),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        minHeight: 8,
                                        value: d.resumen.total == 0 ? 0 : (d.resumen.porEstrellas[e] ?? 0) / d.resumen.total,
                                        backgroundColor: c.surfaceContainerHighest,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text('${d.resumen.porEstrellas[e] ?? 0}', textAlign: TextAlign.end, style: textos.bodySmall),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppEspacios.m),
              if (d.resenas.items.isEmpty)
                const EstadoVacio(
                  icono: Icons.star_outline_rounded,
                  titulo: 'Todavía no tienes reseñas',
                  texto: 'Los clientes pueden calificarte cuando reciben su pedido.',
                )
              else
                for (final r in d.resenas.items) ...[
                  TarjetaResena(
                    resena: r,
                    accion: TextButton.icon(
                      onPressed: () => _responder(context, ref, r),
                      icon: const Icon(Icons.reply, size: 18),
                      label: Text(r.respuesta == null ? 'Responder' : 'Editar respuesta'),
                    ),
                  ),
                  const SizedBox(height: AppEspacios.s),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
