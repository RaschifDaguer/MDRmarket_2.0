import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivo_elegido.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/perfil_repository.dart';
import '../domain/faltante.dart';

/// Hoja inferior para subir la foto de un documento que falta (carnet,
/// licencia, RUAT…). Devuelve `true` si se subió.
Future<bool> mostrarSubirDocumento(BuildContext context, Faltante faltante) async {
  final subido = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SubirDocumento(faltante),
  );
  return subido ?? false;
}

class _SubirDocumento extends ConsumerStatefulWidget {
  const _SubirDocumento(this.faltante);

  final Faltante faltante;

  @override
  ConsumerState<_SubirDocumento> createState() => _SubirDocumentoState();
}

class _SubirDocumentoState extends ConsumerState<_SubirDocumento> {
  ArchivoElegido? _archivo;
  bool _enviando = false;
  String? _error;

  Future<void> _subir() async {
    if (_archivo == null) {
      setState(() => _error = 'Elige la foto primero.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(perfilRepositoryProvider).subirDocumento(
            widget.faltante.documento!,
            _archivo!,
            negocioId: widget.faltante.negocioId,
            vehiculoId: widget.faltante.vehiculoId,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errorDe('archivo') ?? e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.faltante.texto.replaceFirst('Foto: ', '');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppEspacios.l,
        0,
        AppEspacios.l,
        AppEspacios.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppEspacios.xs),
          Text(
            'Que se lea bien y sin reflejos. Solo lo ve el equipo de MDR Market.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppEspacios.m),
          SelectorFoto(
            valor: _archivo,
            texto: titulo,
            icono: Icons.badge_outlined,
            error: _error,
            alElegir: (a) => setState(() {
              _archivo = a;
              _error = null;
            }),
          ),
          const SizedBox(height: AppEspacios.l),
          BotonPrincipal(texto: 'Subir foto', icono: Icons.upload_outlined, cargando: _enviando, onPressed: _subir),
        ],
      ),
    );
  }
}
