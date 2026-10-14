import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/coordenada.dart';
import '../../../core/maps/selector_ubicacion.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';
import '../domain/direccion.dart';

/// Hoja para guardar una dirección nueva. Devuelve la dirección guardada.
Future<Direccion?> mostrarNuevaDireccion(BuildContext context) {
  return showModalBottomSheet<Direccion>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _NuevaDireccion(),
  );
}

class _NuevaDireccion extends ConsumerStatefulWidget {
  const _NuevaDireccion();

  @override
  ConsumerState<_NuevaDireccion> createState() => _NuevaDireccionState();
}

class _NuevaDireccionState extends ConsumerState<_NuevaDireccion> {
  final _form = GlobalKey<FormState>();
  final _direccion = TextEditingController();
  final _referencia = TextEditingController();
  String _etiqueta = 'Casa';
  Coordenada? _ubicacion;
  bool _predeterminada = false;
  bool _guardando = false;
  Map<String, String> _errores = {};

  @override
  void dispose() {
    _direccion.dispose();
    _referencia.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final ok = _form.currentState!.validate();
    if (_ubicacion == null) {
      setState(() => _errores = {'ubicacion': 'Marca dónde quieres recibir tu pedido.'});
    }
    if (!ok || _ubicacion == null) return;

    setState(() {
      _guardando = true;
      _errores = {};
    });
    try {
      final direccion = await ref.read(pedidosRepositoryProvider).guardarDireccion(
            etiqueta: _etiqueta,
            direccion: _direccion.text.trim(),
            referencia: _referencia.text.trim().isEmpty ? null : _referencia.text.trim(),
            ubicacion: _ubicacion!,
            predeterminada: _predeterminada,
          );
      ref.invalidate(direccionesProvider);
      if (mounted) Navigator.pop(context, direccion);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errores = {
          for (final campo in e.errores.keys)
            (campo == 'latitud' || campo == 'longitud' ? 'ubicacion' : campo): e.errorDe(campo)!,
        };
        if (_errores.isEmpty) _errores = {'ubicacion': e.mensaje};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppEspacios.l, 0, AppEspacios.l, AppEspacios.l),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nueva dirección', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppEspacios.m),
                Wrap(
                  spacing: AppEspacios.s,
                  children: [
                    for (final (texto, icono) in [
                      ('Casa', Icons.home_outlined),
                      ('Trabajo', Icons.work_outline),
                      ('Otro', Icons.place_outlined),
                    ])
                      ChoiceChip(
                        avatar: Icon(icono, size: 18),
                        label: Text(texto),
                        selected: _etiqueta == texto,
                        onSelected: (_) => setState(() => _etiqueta = texto),
                      ),
                  ],
                ),
                const SizedBox(height: AppEspacios.m),
                SelectorUbicacion(
                  valor: _ubicacion,
                  error: _errores['ubicacion'],
                  alCambiar: (punto) => setState(() {
                    _ubicacion = punto;
                    _errores = {..._errores}..remove('ubicacion');
                  }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _direccion,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Ej. Calle Libertad 123, 2do anillo',
                    prefixIcon: Icon(Icons.signpost_outlined),
                  ),
                  forceErrorText: _errores['direccion'],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe la dirección' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _referencia,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                    hintText: 'Ej. Portón negro, al lado de la farmacia',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _predeterminada,
                  onChanged: (v) => setState(() => _predeterminada = v ?? false),
                  title: const Text('Usar siempre esta dirección'),
                ),
                const SizedBox(height: AppEspacios.s),
                BotonPrincipal(texto: 'Guardar dirección', icono: Icons.check, cargando: _guardando, onPressed: _guardar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
