import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/pagina.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mi_negocio_repository.dart';
import '../domain/finanzas.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';

final _registrosProvider = FutureProvider.family<Pagina<Registro>, ({int negocioId, String? tipo})>(
  (ref, filtro) => ref.watch(miNegocioRepositoryProvider).registros(filtro.negocioId, tipo: filtro.tipo),
);

/// Compras de mercadería, gastos y ventas (las ventas se anotan solas).
class RegistrosScreen extends StatelessWidget {
  const RegistrosScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ConNegocio(titulo: 'Compras y gastos', builder: (negocio) => _Registros(negocio: negocio));
}

class _Registros extends ConsumerStatefulWidget {
  const _Registros({required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<_Registros> createState() => _RegistrosState();
}

class _RegistrosState extends ConsumerState<_Registros> {
  String? _tipo;

  ({int negocioId, String? tipo}) get _filtro => (negocioId: widget.negocio.id, tipo: _tipo);

  void _refrescar() {
    ref.invalidate(_registrosProvider);
    ref.invalidate(resumenNegocioProvider(widget.negocio.id));
    ref.invalidate(misProductosProvider(widget.negocio.id)); // la compra suma stock
  }

  Future<void> _borrar(Registro r) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Borrar este registro?'),
        content: Text(r.tipo == 'compra'
            ? 'También se restan del stock las ${r.cantidad} unidades que sumó esta compra.'
            : r.titulo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(miNegocioRepositoryProvider).borrarRegistro(widget.negocio.id, r.id);
      _refrescar();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.errorDe('registro') ?? e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final registros = ref.watch(_registrosProvider(_filtro));
    final c = Theme.of(context).colorScheme;

    return Pantalla(
      titulo: 'Compras y gastos',
      abajo: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: BotonPrincipal(
          key: const Key('nuevo-registro'),
          texto: 'Anotar compra o gasto',
          icono: Icons.add,
          onPressed: () async {
            if (await _mostrarNuevoRegistro(context, widget.negocio)) _refrescar();
          },
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m, vertical: AppEspacios.s),
              children: [
                for (final (valor, texto) in [(null, 'Todo'), ('compra', 'Compras'), ('gasto', 'Gastos'), ('venta', 'Ventas')])
                  Padding(
                    padding: const EdgeInsets.only(right: AppEspacios.s),
                    child: ChoiceChip(label: Text(texto), selected: _tipo == valor, onSelected: (_) => setState(() => _tipo = valor)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(_registrosProvider(_filtro).future),
              child: registros.when(
                skipLoadingOnRefresh: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [VistaError(error: e, alReintentar: () => ref.invalidate(_registrosProvider(_filtro)))]),
                data: (pagina) => pagina.items.isEmpty
                    ? ListView(children: const [
                        EstadoVacio(
                          icono: Icons.receipt_long_outlined,
                          titulo: 'Nada anotado todavía',
                          texto: 'Anota lo que compras para vender (suma stock y guarda el costo) y tus gastos '
                              '(alquiler, luz, bolsas…). Así tus ganancias salen exactas.',
                        ),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppEspacios.m, 0, AppEspacios.m, AppEspacios.l),
                        children: [
                          for (final r in pagina.items)
                            Card(
                              margin: const EdgeInsets.only(bottom: AppEspacios.s),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: r.esIngreso ? c.primaryContainer : c.errorContainer,
                                  child: Icon(
                                    switch (r.tipo) {
                                      'compra' => Icons.shopping_cart_outlined,
                                      'venta' => Icons.point_of_sale_outlined,
                                      'comision' => Icons.percent,
                                      _ => Icons.receipt_outlined,
                                    },
                                    color: r.esIngreso ? c.onPrimaryContainer : c.onErrorContainer,
                                  ),
                                ),
                                title: Text(r.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text([
                                  Formato.fecha(r.fecha),
                                  if (r.proveedor != null) r.proveedor!,
                                  if (r.pedidoId != null) 'Pedido #${r.pedidoId}',
                                ].join(' · ')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${r.esIngreso ? '+' : '−'} ${Formato.bs(r.monto)}',
                                      style: TextStyle(color: r.esIngreso ? c.primary : c.error, fontWeight: FontWeight.w600),
                                    ),
                                    if (r.sePuedeBorrar)
                                      IconButton(
                                        tooltip: 'Borrar',
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        onPressed: () => _borrar(r),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja para anotar una compra de mercadería o un gasto. true = se guardó.
Future<bool> _mostrarNuevoRegistro(BuildContext context, Negocio negocio) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NuevoRegistro(negocio: negocio),
  );
  return guardado ?? false;
}

class _NuevoRegistro extends ConsumerStatefulWidget {
  const _NuevoRegistro({required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<_NuevoRegistro> createState() => _NuevoRegistroState();
}

class _NuevoRegistroState extends ConsumerState<_NuevoRegistro> {
  final _form = GlobalKey<FormState>();
  String _tipo = 'compra';
  int? _productoId;
  final _cantidad = TextEditingController();
  final _monto = TextEditingController();
  final _texto = TextEditingController(); // proveedor (compra) o en qué se gastó (gasto)
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  String? _error;

  static double? _numero(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_cantidad, _monto, _texto]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final repo = ref.read(miNegocioRepositoryProvider);
    final hoy = DateUtils.isSameDay(_fecha, DateTime.now());
    try {
      if (_tipo == 'compra') {
        await repo.registrarCompra(
          widget.negocio.id,
          productoId: _productoId!,
          cantidad: int.parse(_cantidad.text.trim()),
          costoUnitario: _numero(_monto.text)!,
          proveedor: _texto.text,
          fecha: hoy ? null : _fecha,
        );
      } else {
        await repo.registrarGasto(widget.negocio.id, descripcion: _texto.text, monto: _numero(_monto.text)!, fecha: hoy ? null : _fecha);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errores.values.firstOrNull?.firstOrNull ?? e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(misProductosProvider(widget.negocio.id)).value ?? const [];
    final compra = _tipo == 'compra';
    const espacio = SizedBox(height: 14);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppEspacios.l, 0, AppEspacios.l, AppEspacios.l),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'compra', icon: Icon(Icons.shopping_cart_outlined), label: Text('Compra')),
                  ButtonSegment(value: 'gasto', icon: Icon(Icons.receipt_outlined), label: Text('Gasto')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: AppEspacios.s),
              Text(
                compra
                    ? 'Mercadería que compraste para vender: se suma al stock y se guarda su costo.'
                    : 'Otros gastos del negocio: alquiler, luz, bolsas, transporte…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppEspacios.m),
              if (compra) ...[
                DropdownButtonFormField<int>(
                  initialValue: _productoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Producto'),
                  items: [
                    for (final p in productos)
                      DropdownMenuItem(value: p.id, child: Text(p.nombre, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _productoId = v),
                  validator: (v) => v == null ? 'Elige el producto' : null,
                ),
                espacio,
                TextFormField(
                  controller: _cantidad,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad', suffixText: 'unidades'),
                  validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) < 1 ? 'Escribe cuántas compraste' : null,
                ),
                espacio,
              ],
              TextFormField(
                controller: _monto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: compra ? 'Costo de cada unidad' : 'Monto', prefixText: 'Bs '),
                validator: (v) => (_numero(v ?? '') ?? 0) <= 0 ? 'Escribe el monto' : null,
              ),
              espacio,
              TextFormField(
                controller: _texto,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: compra ? 'Proveedor (opcional)' : '¿En qué gastaste?',
                  hintText: compra ? 'Ej. Mercado Mutualista' : 'Ej. Alquiler de octubre',
                ),
                validator: (v) => !compra && (v == null || v.trim().isEmpty) ? 'Escribe en qué gastaste' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text('Fecha: ${Formato.fecha(_fecha)}'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (fecha != null) setState(() => _fecha = fecha);
                },
              ),
              if (_error != null) ...[AvisoError(_error!), const SizedBox(height: AppEspacios.m)],
              BotonPrincipal(texto: 'Guardar', icono: Icons.check, cargando: _guardando, onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}
