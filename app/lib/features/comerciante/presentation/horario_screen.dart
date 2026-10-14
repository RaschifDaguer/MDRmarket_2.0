import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mi_negocio_repository.dart';
import '../data/negocio_repository.dart';
import '../domain/horario.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';

/// Horario de atención: qué días abre y de qué hora a qué hora.
class HorarioScreen extends StatelessWidget {
  const HorarioScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ConNegocio(titulo: 'Horario de atención', builder: (negocio) => _Horario(negocio: negocio));
}

class _Horario extends ConsumerStatefulWidget {
  const _Horario({required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<_Horario> createState() => _HorarioState();
}

class _HorarioState extends ConsumerState<_Horario> {
  /// Un tramo por día (1 = lunes … 7 = domingo); null = cerrado ese día.
  late final Map<int, ({String apertura, String cierre})?> _dias = {
    for (var d = 1; d <= 7; d++)
      d: widget.negocio.horarios
          .where((h) => h.diaSemana == d)
          .map((h) => (apertura: h.apertura, cierre: h.cierre))
          .firstOrNull,
  };
  bool _guardando = false;
  String? _error;

  Future<void> _elegirHora(int dia, bool esApertura) async {
    final actual = _dias[dia]!;
    final texto = esApertura ? actual.apertura : actual.cierre;
    final partes = texto.split(':');
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1])),
    );
    if (hora == null) return;
    final nueva = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    setState(() => _dias[dia] = esApertura ? (apertura: nueva, cierre: actual.cierre) : (apertura: actual.apertura, cierre: nueva));
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(miNegocioRepositoryProvider).horario(widget.negocio.id, [
        for (final MapEntry(key: dia, value: tramo) in _dias.entries)
          if (tramo != null) Horario(diaSemana: dia, apertura: tramo.apertura, cierre: tramo.cierre),
      ]);
      ref.invalidate(misNegociosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horario guardado')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errores.values.firstOrNull?.firstOrNull ?? e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pantalla(
      titulo: 'Horario de atención',
      abajo: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: BotonPrincipal(texto: 'Guardar horario', icono: Icons.check, cargando: _guardando, onPressed: _guardar),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          Text('El horario es informativo para tus clientes. Para dejar de recibir pedidos en el momento, '
              'usa el interruptor "Abierto" del Resumen.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppEspacios.m),
          for (var dia = 1; dia <= 7; dia++)
            Card(
              margin: const EdgeInsets.only(bottom: AppEspacios.s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m - 4, vertical: AppEspacios.xs),
                child: Row(
                  children: [
                    Switch(
                      value: _dias[dia] != null,
                      onChanged: (abre) =>
                          setState(() => _dias[dia] = abre ? (apertura: '08:00', cierre: '20:00') : null),
                    ),
                    const SizedBox(width: AppEspacios.s),
                    Expanded(child: Text(Horario.dias[dia - 1])),
                    if (_dias[dia] == null)
                      Text('Cerrado', style: Theme.of(context).textTheme.bodySmall)
                    else ...[
                      TextButton(onPressed: () => _elegirHora(dia, true), child: Text(_dias[dia]!.apertura)),
                      const Text('–'),
                      TextButton(onPressed: () => _elegirHora(dia, false), child: Text(_dias[dia]!.cierre)),
                    ],
                  ],
                ),
              ),
            ),
          if (_error != null) AvisoError(_error!),
        ],
      ),
    );
  }
}
