import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../comerciante/domain/documento_subido.dart';
import '../../perfil/data/perfil_repository.dart';
import '../../perfil/domain/faltante.dart';
import '../../perfil/presentation/subir_documento_sheet.dart';

/// Cómo va un documento del repartidor.
enum EstadoDocumento {
  rechazado('Rechazado', Icons.error_outline),
  falta('Falta subir', Icons.radio_button_unchecked),
  enRevision('En revisión', Icons.hourglass_top),
  aprobado('Aprobado', Icons.check_circle);

  const EstadoDocumento(this.texto, this.icono);
  final String texto;
  final IconData icono;
}

/// Una fila de "En revisión": el documento, cómo va y (si hay que subirlo) qué subir.
class FilaDocumento {
  const FilaDocumento({required this.titulo, required this.estado, this.observacion, this.faltante});

  final String titulo;
  final EstadoDocumento estado;

  /// Por qué se rechazó (lo escribe el admin).
  final String? observacion;

  /// Lo que se sube con "Subir" o "Volver a subir".
  final Faltante? faltante;

  /// Une lo que subió ([documentos]) con lo que le falta ([faltantes], de la
  /// API: ya incluye los rechazados y pide el SOAT solo si el vehículo tiene
  /// placa). Los documentos de un negocio no cuentan.
  static List<FilaDocumento> armar(List<DocumentoSubido> documentos, List<Faltante> faltantes) {
    // La API los manda del más nuevo al más viejo: vale el último de cada uno.
    final vistos = <String>{};
    final actuales = [
      for (final d in documentos)
        if (d.negocioId == null && vistos.add('${d.tipo}:${d.vehiculoId}')) d,
    ];
    DocumentoSubido? de(Faltante f) =>
        actuales.where((d) => d.tipo == f.documento && d.vehiculoId == f.vehiculoId).firstOrNull;

    final filas = <FilaDocumento>[
      for (final f in faltantes.where((f) => f.esDocumento))
        if (de(f) case final d? when d.rechazado)
          FilaDocumento(titulo: d.nombre, estado: EstadoDocumento.rechazado, observacion: d.observacion, faltante: f)
        else
          FilaDocumento(titulo: f.texto, estado: EstadoDocumento.falta, faltante: f),
      for (final d in actuales.where((d) => !d.rechazado))
        FilaDocumento(titulo: d.nombre, estado: d.aprobado ? EstadoDocumento.aprobado : EstadoDocumento.enRevision),
    ];
    return filas..sort((a, b) => a.estado.index.compareTo(b.estado.index));
  }
}

/// "Estamos revisando tus datos": cuántos documentos lleva y el estado de cada
/// uno (aprobado, en revisión, rechazado con su observación o falta subir),
/// con "Subir" o "Volver a subir".
class RevisionRepartidor extends ConsumerWidget {
  const RevisionRepartidor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faltantes = ref.watch(faltantesProvider('repartidor'));
    final documentos = ref.watch(misDocumentosProvider);
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    Future<void> actualizar() async {
      ref.invalidate(misDocumentosProvider);
      ref.invalidate(faltantesProvider('repartidor'));
      await ref.read(faltantesProvider('repartidor').future);
    }

    if (!faltantes.hasValue || !documentos.hasValue) {
      final error = faltantes.error ?? documentos.error;
      return error != null
          ? VistaError(error: error, alReintentar: actualizar)
          : const Center(child: CircularProgressIndicator());
    }

    final filas = FilaDocumento.armar(documentos.value!, faltantes.value!);
    final otros = faltantes.value!.where((f) => !f.esDocumento).toList();
    final listos = filas
        .where((f) => f.estado == EstadoDocumento.aprobado || f.estado == EstadoDocumento.enRevision)
        .length;
    final completo = filas.isNotEmpty && listos == filas.length && otros.isEmpty;

    Future<void> subir(Faltante f) async {
      if (await mostrarSubirDocumento(context, f)) {
        ref.invalidate(misDocumentosProvider);
        ref.invalidate(faltantesProvider('repartidor'));
      }
    }

    return RefreshIndicator(
      onRefresh: actualizar,
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Paso 3 de 3 · Documentos', style: textos.labelLarge?.copyWith(color: c.primary)),
                  const SizedBox(height: AppEspacios.xs),
                  Text(
                    'Estamos revisando tus datos',
                    style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppEspacios.xs),
                  Text.rich(
                    key: const Key('llevas-documentos'),
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Llevas '),
                        TextSpan(
                          text: '$listos de ${filas.length} documentos',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: completo
                              ? '. El equipo de MDR Market los está revisando y te avisa cuando puedas repartir.'
                              : '. Cuando estén todos, el equipo de MDR Market los revisa y te avisa.',
                        ),
                      ],
                    ),
                    style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                  if (filas.isNotEmpty) ...[
                    const SizedBox(height: AppEspacios.s),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: listos / filas.length, minHeight: 8),
                    ),
                  ],
                  const SizedBox(height: AppEspacios.m),
                  for (final f in otros)
                    Card(
                      child: ListTile(
                        key: Key('falta-dato-${f.codigo}'),
                        leading: Icon(Icons.radio_button_unchecked, color: c.outline),
                        title: Text(f.texto),
                        trailing: f.codigo == 'vehiculo'
                            ? FilledButton.tonal(
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                                onPressed: () => context.go('/registrar-repartidor'),
                                child: const Text('Registrar'),
                              )
                            : null,
                      ),
                    ),
                  for (final (i, f) in filas.indexed) _Fila(fila: f, alSubir: subir, indice: i),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.fila, required this.alSubir, required this.indice});

  final FilaDocumento fila;
  final ValueChanged<Faltante> alSubir;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final color = switch (fila.estado) {
      EstadoDocumento.aprobado => c.primary,
      EstadoDocumento.enRevision => c.tertiary,
      EstadoDocumento.rechazado => c.error,
      EstadoDocumento.falta => c.outline,
    };
    final boton = switch (fila.estado) {
      EstadoDocumento.falta => 'Subir',
      EstadoDocumento.rechazado => 'Volver a subir',
      _ => null,
    };

    return Card(
      key: Key('documento-$indice'),
      child: ListTile(
        leading: Icon(fila.estado.icono, color: color),
        title: Text(fila.titulo),
        subtitle: Text(
          [fila.estado.texto, ?fila.observacion].join(' · '),
          style: textos.bodySmall?.copyWith(color: fila.estado == EstadoDocumento.rechazado ? c.error : color),
        ),
        trailing: boton == null
            ? null
            : FilledButton.tonal(
                key: Key('subir-$indice'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => alSubir(fila.faltante!),
                child: Text(boton),
              ),
      ),
    );
  }
}
