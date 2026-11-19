import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/terminos_repository.dart';

/// Términos y condiciones de MDR Market.
///
/// - Solo para leer (`/terminos`): se abre desde "Crear cuenta" o la cuenta.
/// - Para aceptar (`/aceptar-terminos`, [aceptar] = true): cuentas antiguas o
///   términos nuevos. No se puede seguir usando la app sin aceptarlos; el
///   router vuelve a inicio cuando la API confirma.
class TerminosScreen extends ConsumerStatefulWidget {
  const TerminosScreen({super.key, this.aceptar = false});

  final bool aceptar;

  @override
  ConsumerState<TerminosScreen> createState() => _TerminosScreenState();
}

class _TerminosScreenState extends ConsumerState<TerminosScreen> {
  bool _marcado = false;
  bool _enviando = false;
  String? _error;

  Future<void> _aceptar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final usuario = await ref.read(terminosRepositoryProvider).aceptar();
      ref.read(authControllerProvider.notifier).actualizarUsuario(usuario);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminos = ref.watch(terminosProvider);
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Pantalla(
      titulo: 'Términos y condiciones',
      acciones: [
        if (widget.aceptar)
          TextButton(
            onPressed: _enviando ? null : () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Salir'),
          ),
      ],
      abajo: widget.aceptar && terminos.hasValue ? _barraAceptar(terminos.value!) : null,
      child: terminos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(terminosProvider)),
        data: (t) => ListView(
          key: const Key('terminos-texto'),
          padding: const EdgeInsets.all(AppEspacios.m + 4),
          children: [
            if (widget.aceptar) ...[
              Text('Actualizamos nuestros términos', style: textos.titleLarge),
              const SizedBox(height: AppEspacios.xs),
              Text('Para seguir usando MDR Market, léelos y acéptalos.', style: textos.bodyMedium),
              const SizedBox(height: AppEspacios.m),
            ],
            Text('Actualizados el ${t.actualizado}', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: AppEspacios.s),
            Container(
              padding: const EdgeInsets.all(AppEspacios.m),
              decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(t.resumen, style: textos.bodyMedium?.copyWith(color: c.onTertiaryContainer)),
            ),
            for (final s in t.secciones) ...[
              const SizedBox(height: AppEspacios.l),
              Text(s.titulo, style: textos.titleMedium),
              const SizedBox(height: AppEspacios.xs),
              for (final p in s.parrafos)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppEspacios.s),
                  child: Text(p, style: textos.bodyMedium?.copyWith(height: 1.45)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _barraAceptar(Terminos t) {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.s, AppEspacios.m, AppEspacios.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              key: const Key('terminos-casilla'),
              value: _marcado,
              onChanged: _enviando ? null : (v) => setState(() => _marcado = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(t.declaracion),
            ),
            if (_error != null) ...[AvisoError(_error!), const SizedBox(height: AppEspacios.s)],
            BotonPrincipal(
              key: const Key('terminos-aceptar'),
              texto: 'Aceptar y continuar',
              cargando: _enviando,
              onPressed: _marcado ? _aceptar : null,
            ),
          ],
        ),
      ),
    );
  }
}
