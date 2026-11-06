import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../perfil/data/perfil_repository.dart';
import '../../perfil/domain/faltante.dart';
import '../../perfil/presentation/subir_documento_sheet.dart';

/// "Te falta subir…" del repartidor: cada foto con su botón Subir (las del
/// vehículo se suben con su vehiculo_id) y, si no registró el vehículo, el
/// botón para hacerlo.
class FaltantesRepartidor extends ConsumerWidget {
  const FaltantesRepartidor(this.faltantes, {super.key});

  final List<Faltante> faltantes;

  /// El tema da a los botones ancho completo; aquí van al lado del texto.
  static final _compacto = FilledButton.styleFrom(minimumSize: const Size(0, 40));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Tarjeta3D(
      inclinacionMax: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSeccion('Te falta subir…', Icons.checklist_rtl),
          for (final f in faltantes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppEspacios.xs),
              child: Row(
                children: [
                  Icon(Icons.radio_button_unchecked, size: 18, color: c.outline),
                  const SizedBox(width: AppEspacios.s + 2),
                  Expanded(child: Text(f.texto, style: textos.bodyMedium)),
                  if (f.esDocumento)
                    FilledButton.tonalIcon(
                      style: _compacto,
                      onPressed: () async {
                        if (await mostrarSubirDocumento(context, f)) {
                          ref.invalidate(faltantesProvider('repartidor'));
                        }
                      },
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: const Text('Subir'),
                    )
                  else if (f.codigo == 'vehiculo')
                    FilledButton.tonal(
                      style: _compacto,
                      onPressed: () => context.go('/registrar-repartidor'),
                      child: const Text('Registrar'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ya subió todo: solo falta que el administrador lo revise.
class TodoEnviado extends StatelessWidget {
  const TodoEnviado({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Tarjeta3D(
      inclinacionMax: 2,
      child: Row(
        children: [
          Icon(Icons.task_alt, size: 32, color: c.primary),
          const SizedBox(width: AppEspacios.m - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ya enviaste todo', style: textos.titleMedium),
                Text(
                  'Tu solicitud está en revisión del administrador. Te avisaremos cuando puedas empezar a repartir.',
                  style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
