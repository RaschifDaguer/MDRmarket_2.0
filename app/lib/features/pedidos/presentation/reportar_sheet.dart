import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';

/// "Hubo un problema": con la tienda o con el repartidor, el motivo (de la
/// API) y qué pasó. Lo revisa el equipo de MDR Market. Devuelve true si se envió.
Future<bool> mostrarReportar(BuildContext context, Pedido pedido) async {
  final enviado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Reportar(pedido: pedido),
  );
  return enviado ?? false;
}

class _Reportar extends ConsumerStatefulWidget {
  const _Reportar({required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<_Reportar> createState() => _ReportarState();
}

class _ReportarState extends ConsumerState<_Reportar> {
  final _descripcion = TextEditingController();
  String _sobre = 'negocio';
  String? _motivo;
  List<MotivoReporte>? _motivos;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarMotivos();
  }

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarMotivos() async {
    setState(() {
      _motivos = null;
      _motivo = null;
    });
    try {
      final motivos = await ref.read(pedidosRepositoryProvider).motivosReporte(_sobre);
      if (mounted) setState(() => _motivos = motivos);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final mensaje = await ref
          .read(pedidosRepositoryProvider)
          .reportar(widget.pedido.id, sobre: _sobre, motivo: _motivo!, descripcion: _descripcion.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.errores.values.firstOrNull?.firstOrNull ?? e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final conRepartidor = widget.pedido.repartidorId != null || widget.pedido.tieneRepartidor;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppEspacios.m,
        0,
        AppEspacios.m,
        MediaQuery.viewInsetsOf(context).bottom + AppEspacios.m,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Qué pasó?', style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppEspacios.xs),
            Text('El equipo de MDR Market lo revisa y te responde en tus notificaciones.', style: textos.bodySmall),
            const SizedBox(height: AppEspacios.m),
            if (conRepartidor)
              SegmentedButton<String>(
                key: const Key('reporte-sobre'),
                segments: [
                  ButtonSegment(
                    value: 'negocio',
                    label: Text('La tienda'),
                    icon: const Icon(Icons.storefront_outlined),
                  ),
                  const ButtonSegment(
                    value: 'repartidor',
                    label: Text('El repartidor'),
                    icon: Icon(Icons.delivery_dining_outlined),
                  ),
                ],
                selected: {_sobre},
                onSelectionChanged: (s) {
                  setState(() => _sobre = s.first);
                  _cargarMotivos();
                },
              ),
            const SizedBox(height: AppEspacios.m),
            if (_motivos == null && _error == null)
              const Center(
                child: Padding(padding: EdgeInsets.all(AppEspacios.m), child: CircularProgressIndicator()),
              )
            else if (_motivos != null)
              Wrap(
                spacing: AppEspacios.s,
                runSpacing: AppEspacios.s,
                children: [
                  for (final m in _motivos!)
                    ChoiceChip(
                      key: Key('motivo-${m.codigo}'),
                      label: Text(m.nombre),
                      selected: _motivo == m.codigo,
                      onSelected: (_) => setState(() => _motivo = m.codigo),
                    ),
                ],
              ),
            const SizedBox(height: AppEspacios.m),
            TextField(
              key: const Key('reporte-descripcion'),
              controller: _descripcion,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Cuéntanos más (opcional)'),
            ),
            if (_error != null) ...[AvisoError(_error!), const SizedBox(height: AppEspacios.s)],
            BotonPrincipal(
              key: const Key('enviar-reporte'),
              texto: 'Enviar',
              icono: Icons.flag_outlined,
              cargando: _enviando,
              onPressed: _motivo == null ? null : _enviar,
            ),
          ],
        ),
      ),
    );
  }
}
