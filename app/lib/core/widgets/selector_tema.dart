import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferencias.dart';
import '../theme/app_espacios.dart';

/// Tema de la app: el del sistema, claro u oscuro. Es una sola preferencia
/// para toda la app (se guarda en el teléfono): si se cambia en la cuenta del
/// cliente, en "Más" del comercio o en la cuenta del repartidor, cambia en todas.
class SelectorTema extends ConsumerWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoTemaProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m, vertical: AppEspacios.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.dark_mode_outlined),
              SizedBox(width: AppEspacios.m),
              Text('Tema'),
            ],
          ),
          const SizedBox(height: AppEspacios.s),
          SegmentedButton<ThemeMode>(
            key: const Key('selector-tema'),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
            ],
            selected: {modo},
            onSelectionChanged: (s) => ref.read(modoTemaProvider.notifier).cambiar(s.first),
          ),
        ],
      ),
    );
  }
}
