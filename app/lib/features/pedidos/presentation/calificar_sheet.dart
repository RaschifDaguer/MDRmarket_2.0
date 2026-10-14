import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';

/// Hoja para calificar un producto o un negocio (1 a 5 estrellas y un
/// comentario). Si ya lo calificó, edita la misma reseña. Devuelve true si guardó.
Future<bool> mostrarCalificar(
  BuildContext context, {
  required String titulo,
  int? productoId,
  int? negocioId,
  int? estrellas,
  String? comentario,
}) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Calificar(
      titulo: titulo,
      productoId: productoId,
      negocioId: negocioId,
      estrellas: estrellas,
      comentario: comentario,
    ),
  );
  return guardado ?? false;
}

class _Calificar extends ConsumerStatefulWidget {
  const _Calificar({required this.titulo, this.productoId, this.negocioId, this.estrellas, this.comentario});

  final String titulo;
  final int? productoId;
  final int? negocioId;
  final int? estrellas;
  final String? comentario;

  @override
  ConsumerState<_Calificar> createState() => _CalificarState();
}

class _CalificarState extends ConsumerState<_Calificar> {
  late int _estrellas = widget.estrellas ?? 0;
  late final _comentario = TextEditingController(text: widget.comentario);
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_estrellas == 0) {
      setState(() => _error = 'Elige de 1 a 5 estrellas.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(pedidosRepositoryProvider).calificar(
            productoId: widget.productoId,
            negocioId: widget.negocioId,
            estrellas: _estrellas,
            comentario: _comentario.text,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const textos = ['', 'Muy malo', 'Malo', 'Regular', 'Bueno', '¡Excelente!'];
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppEspacios.l, 0, AppEspacios.l, AppEspacios.l + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.titulo, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppEspacios.s),
          Center(child: SelectorEstrellas(valor: _estrellas, alCambiar: (e) => setState(() => _estrellas = e))),
          Text(textos[_estrellas], textAlign: TextAlign.center),
          const SizedBox(height: AppEspacios.m),
          TextField(
            controller: _comentario,
            maxLines: 3,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Comentario (opcional)', alignLabelWithHint: true),
          ),
          if (_error != null) ...[AvisoError(_error!), const SizedBox(height: AppEspacios.m)],
          BotonPrincipal(texto: 'Guardar', icono: Icons.star_rounded, cargando: _guardando, onPressed: _guardar),
        ],
      ),
    );
  }
}
