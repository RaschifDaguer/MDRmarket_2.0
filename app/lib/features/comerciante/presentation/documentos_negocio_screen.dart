import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../perfil/data/perfil_repository.dart';
import '../../perfil/domain/faltante.dart';
import '../../perfil/presentation/subir_documento_sheet.dart';
import '../data/mi_negocio_repository.dart';
import '../domain/documento_subido.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';

/// "Más · Documentos": los que subió (del negocio y suyos) con cómo va su
/// revisión, lo que falta subir y volver a subir uno rechazado.
class DocumentosNegocioScreen extends StatelessWidget {
  const DocumentosNegocioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ConNegocio(
      titulo: 'Documentos',
      builder: (negocio) => _Documentos(negocio: negocio),
    );
  }
}

class _Documentos extends ConsumerWidget {
  const _Documentos({required this.negocio});

  final Negocio negocio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentos = ref.watch(documentosNegocioProvider);
    final faltan = (ref.watch(faltantesProvider('comerciante')).value ?? const <Faltante>[])
        .where((f) => f.esDocumento)
        .toList();

    Future<void> subir(Faltante f) async {
      if (await mostrarSubirDocumento(context, f)) {
        ref.invalidate(documentosNegocioProvider);
        ref.invalidate(faltantesProvider('comerciante'));
      }
    }

    return Pantalla(
      titulo: 'Documentos',
      // Solo, cada pocos segundos: cuando el equipo aprueba o rechaza un documento, se ve enseguida.
      child: ActualizacionAutomatica(
        cada: const Duration(seconds: 10),
        alActualizar: () {
          ref.invalidate(documentosNegocioProvider);
          ref.invalidate(faltantesProvider('comerciante'));
        },
        child: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(faltantesProvider('comerciante'));
            return ref.refresh(documentosNegocioProvider.future);
          },
          child: documentos.when(
            skipLoadingOnRefresh: true,
            skipError: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              children: [VistaError(error: e, alReintentar: () => ref.invalidate(documentosNegocioProvider))],
            ),
            data: (lista) {
              // Si hay varios del mismo tipo, vale el último (la API los manda del más nuevo al más viejo).
              final vistos = <String>{};
              final actuales = [
                for (final d in lista)
                  if (vistos.add('${d.tipo}:${d.negocioId}')) d,
              ];
              final delNegocio = actuales.where((d) => d.negocioId == negocio.id).toList();
              final tuyos = actuales.where((d) => d.negocioId == null).toList();

              return ListView(
                padding: const EdgeInsets.all(AppEspacios.m),
                children: [
                  if (faltan.isNotEmpty) ...[
                    const TituloSeccion('Te falta subir', Icons.upload_file_outlined),
                    for (final f in faltan)
                      Card(
                        child: ListTile(
                          key: Key('falta-${f.codigo}'),
                          leading: const Icon(Icons.radio_button_unchecked),
                          title: Text(f.texto),
                          trailing: FilledButton.tonal(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: () => subir(f),
                            child: const Text('Subir'),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppEspacios.m),
                  ],
                  if (delNegocio.isNotEmpty) ...[
                    const TituloSeccion('Del negocio', Icons.storefront_outlined),
                    for (final d in delNegocio) _Fila(documento: d, alResubir: subir),
                    const SizedBox(height: AppEspacios.m),
                  ],
                  if (tuyos.isNotEmpty) ...[
                    const TituloSeccion('Tuyos', Icons.person_outline),
                    for (final d in tuyos) _Fila(documento: d, alResubir: subir),
                  ],
                  if (actuales.isEmpty && faltan.isEmpty)
                    const EstadoVacio(icono: Icons.badge_outlined, titulo: 'Todavía no subiste documentos'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.documento, required this.alResubir});

  final DocumentoSubido documento;
  final ValueChanged<Faltante> alResubir;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final d = documento;
    final (icono, color) = d.aprobado
        ? (Icons.verified, c.primary)
        : d.rechazado
        ? (Icons.error_outline, c.error)
        : (Icons.hourglass_top, c.tertiary);

    return Card(
      child: ListTile(
        key: Key('documento-${d.id}'),
        leading: Icon(icono, color: color),
        title: Text(d.nombre),
        subtitle: Text(
          [d.estadoTexto, if (d.rechazado && d.observacion != null) d.observacion!].join(' · '),
          style: TextStyle(color: d.rechazado ? c.error : null),
        ),
        trailing: d.rechazado
            ? TextButton(
                key: Key('resubir-${d.id}'),
                onPressed: () => alResubir(
                  Faltante(codigo: 'documento.${d.tipo}', texto: d.nombre, documento: d.tipo, negocioId: d.negocioId),
                ),
                child: const Text('Volver a subir'),
              )
            : null,
      ),
    );
  }
}
