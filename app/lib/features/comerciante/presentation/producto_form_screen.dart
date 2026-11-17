import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivo_elegido.dart';
import '../../../core/formato/formato.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../catalogo/data/catalogo_repository.dart';
import '../../catalogo/domain/categoria.dart';
import '../data/mi_negocio_repository.dart';
import '../domain/mi_producto.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';
import 'widgets/fotos_producto.dart';

/// Crear o editar un producto. Con [producto] = editar.
class ProductoFormScreen extends StatelessWidget {
  const ProductoFormScreen({super.key, this.producto});

  final MiProducto? producto;

  @override
  Widget build(BuildContext context) {
    final titulo = producto == null ? 'Nuevo producto' : 'Editar producto';
    return ConNegocio(
      titulo: titulo,
      builder: (negocio) => _Formulario(negocio: negocio, producto: producto, titulo: titulo),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.negocio, required this.producto, required this.titulo});

  final Negocio negocio;
  final MiProducto? producto;
  final String titulo;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _form = GlobalKey<FormState>();
  late final p = widget.producto;
  late final _nombre = TextEditingController(text: p?.nombre);
  late final _descripcion = TextEditingController(text: p?.descripcion);
  late final _precio = TextEditingController(text: _texto(p?.precio));
  late final _costo = TextEditingController(text: _texto(p?.costo));
  late final _precioOferta = TextEditingController(text: _texto(p?.precioOferta));
  late final _stock = TextEditingController(text: p?.stock?.toString() ?? '');

  late int? _categoriaId = p?.categoriaId;
  late bool _enOferta = p?.precioOferta != null;
  // Una oferta que ya venció no se vuelve a mandar (la API pide una fecha futura).
  late DateTime? _ofertaFin = (p?.ofertaFin?.isAfter(DateTime.now()) ?? false) ? p!.ofertaFin : null;
  late bool _disponible = p?.disponible ?? true;
  late int _tamano = p?.tamano ?? 1;

  /// Fotos nuevas que eligió (se suben al guardar) y las que ya tiene.
  final _nuevas = <ArchivoElegido>[];
  late List<FotoProducto> _subidas = [...?p?.imagenes];
  bool _guardando = false;
  Map<String, String> _errores = {};
  String? _errorGeneral;

  static String _texto(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  /// "12,50" o "12.50" → 12.5
  static double? _numero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    // La ganancia se recalcula mientras escribe.
    for (final c in [_precio, _costo, _precioOferta]) {
      c.addListener(_recalcular);
    }
  }

  void _recalcular() => setState(() {});

  /// Lo que gana por cada uno: precio (o el de oferta) − lo que le costó.
  ({double ganancia, double? porcentaje})? get _ganancia {
    final precio = _enOferta ? (_numero(_precioOferta.text) ?? _numero(_precio.text)) : _numero(_precio.text);
    final costo = _numero(_costo.text);
    if (precio == null || costo == null) return null;
    final ganancia = precio - costo;
    return (ganancia: ganancia, porcentaje: precio > 0 ? ganancia / precio * 100 : null);
  }

  Future<void> _quitarSubida(FotoProducto foto) async {
    try {
      final producto = await ref.read(miNegocioRepositoryProvider).borrarFoto(widget.negocio.id, p!.id, foto.id);
      if (mounted) setState(() => _subidas = producto.imagenes);
      _refrescar();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    }
  }

  Future<void> _hacerPortada(FotoProducto foto) async {
    try {
      final producto = await ref.read(miNegocioRepositoryProvider).portada(widget.negocio.id, p!.id, foto.id);
      if (mounted) setState(() => _subidas = producto.imagenes);
      _refrescar();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _precio, _costo, _precioOferta, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _errores = {};
      _errorGeneral = null;
    });
    if (!_form.currentState!.validate()) return;

    final precio = _numero(_precio.text)!;
    final datos = DatosProducto(
      nombre: _nombre.text,
      categoriaId: _categoriaId!,
      precio: precio,
      descripcion: _descripcion.text,
      costo: _numero(_costo.text),
      precioOferta: _enOferta ? _numero(_precioOferta.text) : null,
      ofertaFin: _enOferta ? _ofertaFin : null,
      stock: int.parse(_stock.text.trim()),
      disponible: _disponible,
      tamano: _tamano,
    );

    setState(() => _guardando = true);
    try {
      await ref
          .read(miNegocioRepositoryProvider)
          .guardarProducto(widget.negocio.id, datos, productoId: p?.id, fotos: _nuevas);
      _refrescar();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(p == null ? 'Producto agregado' : 'Cambios guardados')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errores = {for (final campo in e.errores.keys) campo: e.errorDe(campo)!};
        if (_errores.isEmpty) _errorGeneral = e.mensaje;
      });
    }
  }

  Future<void> _borrar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Eliminar «${p!.nombre}»?'),
        content: const Text(
          'Sale del catálogo. Los pedidos anteriores lo siguen mostrando. '
          'Si solo quieres dejar de venderlo un tiempo, mejor ocúltalo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(miNegocioRepositoryProvider).borrarProducto(widget.negocio.id, p!.id);
      _refrescar();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    }
  }

  void _refrescar() {
    ref.invalidate(misProductosProvider(widget.negocio.id));
    ref.invalidate(resumenNegocioProvider(widget.negocio.id));
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoriasProvider);
    const espacio = SizedBox(height: 14);

    return Pantalla(
      titulo: widget.titulo,
      acciones: [
        if (p != null)
          IconButton(tooltip: 'Eliminar producto', onPressed: _borrar, icon: const Icon(Icons.delete_outline)),
      ],
      abajo: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: BotonPrincipal(
          texto: p == null ? 'Publicar producto' : 'Guardar cambios',
          icono: Icons.check,
          cargando: _guardando,
          onPressed: _guardar,
        ),
      ),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppEspacios.m),
          children: [
            FotosProducto(
              subidas: _subidas,
              nuevas: _nuevas,
              error: _errores['fotos'] ?? _errores['foto'],
              alAgregar: (f) => setState(() => _nuevas.add(f)),
              alQuitarNueva: (i) => setState(() => _nuevas.removeAt(i)),
              alQuitarSubida: p == null ? null : _quitarSubida,
              alHacerPortada: p == null ? null : _hacerPortada,
            ),
            const SizedBox(height: AppEspacios.l),
            const TituloSeccion('Datos', Icons.inventory_2_outlined),
            TextFormField(
              key: const Key('campo-nombre'),
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Hamburguesa doble con papas'),
              forceErrorText: _errores['nombre'],
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el nombre del producto' : null,
            ),
            espacio,
            categorias.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AvisoError('No se pudieron cargar las categorías: $e'),
              data: (lista) => DropdownButtonFormField<int>(
                key: const Key('campo-categoria'),
                initialValue: _categoriaId,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Categoría', errorText: _errores['categoria_id']),
                items: _opcionesCategoria(lista),
                onChanged: (v) => setState(() => _categoriaId = v),
                validator: (v) => v == null ? 'Elige la categoría' : null,
              ),
            ),
            espacio,
            TextFormField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)', alignLabelWithHint: true),
              forceErrorText: _errores['descripcion'],
            ),
            const SizedBox(height: AppEspacios.s),
            const TituloSeccion('Precio', Icons.sell_outlined),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('campo-precio'),
                    controller: _precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio de venta', prefixText: 'Bs '),
                    forceErrorText: _errores['precio'],
                    validator: (v) {
                      final n = _numero(v ?? '');
                      if (n == null) return 'Escribe el precio';
                      return n < 0.5 ? 'Mínimo Bs 0,50' : null;
                    },
                  ),
                ),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  child: TextFormField(
                    key: const Key('campo-costo'),
                    controller: _costo,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Te costó (opcional)',
                      prefixText: 'Bs ',
                      helperText: 'Para calcular cuánto ganas.',
                      helperMaxLines: 2,
                    ),
                    forceErrorText: _errores['costo'],
                    validator: (v) =>
                        (v != null && v.trim().isNotEmpty && _numero(v) == null) ? 'Número no válido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspacios.s),
            _Ganancia(_ganancia),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enOferta,
              onChanged: (v) => setState(() => _enOferta = v),
              title: const Text('Está en oferta'),
              subtitle: const Text('Se muestra con el precio anterior tachado.'),
            ),
            if (_enOferta) ...[
              TextFormField(
                key: const Key('campo-oferta'),
                controller: _precioOferta,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio de oferta', prefixText: 'Bs '),
                forceErrorText: _errores['precio_oferta'],
                validator: (v) {
                  final oferta = _numero(v ?? '');
                  final precio = _numero(_precio.text);
                  if (oferta == null) return 'Escribe el precio de oferta';
                  if (precio != null && oferta >= precio) return 'Tiene que ser menor al precio normal';
                  return null;
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(_ofertaFin == null ? 'Sin fecha de fin' : 'Hasta el ${Formato.fecha(_ofertaFin)}'),
                subtitle: _errores['oferta_fin'] != null
                    ? Text(_errores['oferta_fin']!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                    : const Text('Opcional: después de esa fecha vuelve al precio normal.'),
                trailing: _ofertaFin == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        tooltip: 'Quitar fecha',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _ofertaFin = null),
                      ),
                onTap: () async {
                  final hoy = DateTime.now();
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: _ofertaFin ?? hoy.add(const Duration(days: 7)),
                    firstDate: hoy,
                    lastDate: hoy.add(const Duration(days: 365)),
                  );
                  if (fecha != null) setState(() => _ofertaFin = fecha);
                },
              ),
            ],
            const SizedBox(height: AppEspacios.s),
            const TituloSeccion('Stock y envío', Icons.local_shipping_outlined),
            // Siempre se pide el stock: al publicar, al menos 1 unidad. Cuando
            // se acaba, el cliente lo ve "Agotado" y aquí se renueva.
            if (p?.sinStock ?? false)
              const Padding(
                key: Key('aviso-agotado'),
                padding: EdgeInsets.only(bottom: AppEspacios.s),
                child: AvisoError('Se agotó: súbele el stock para volver a venderlo.'),
              ),
            TextFormField(
              key: const Key('campo-stock'),
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: p == null ? '¿Cuántas unidades vas a publicar?' : 'Unidades en stock',
                helperText: 'Cuando se acaben, te avisamos para que lo renueves.',
                suffixText: 'unidades',
              ),
              forceErrorText: _errores['stock'],
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null) return 'Escribe cuántas unidades tienes';
                if (p == null && n < 1) return 'Publica al menos 1 unidad';
                return n < 0 ? 'No puede ser negativo' : null;
              },
            ),
            const SizedBox(height: AppEspacios.m),
            Text('¿En qué se puede llevar?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppEspacios.s),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, icon: Icon(Icons.two_wheeler), label: Text('Moto')),
                ButtonSegment(value: 2, icon: Icon(Icons.directions_car_outlined), label: Text('Auto')),
                ButtonSegment(value: 3, icon: Icon(Icons.local_shipping_outlined), label: Text('Camión')),
              ],
              selected: {_tamano},
              onSelectionChanged: (s) => setState(() => _tamano = s.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
              title: const Text('Visible en el catálogo'),
            ),
            if (_errorGeneral != null) ...[const SizedBox(height: AppEspacios.s), AvisoError(_errorGeneral!)],
            const SizedBox(height: AppEspacios.xl),
          ],
        ),
      ),
    );
  }

  /// Subcategorías ("Farmacia y medicamentos"), primero las del rubro del negocio.
  List<DropdownMenuItem<int>> _opcionesCategoria(List<Categoria> principales) {
    final rubro = widget.negocio.categoria?.id;
    final ordenadas = [...principales]..sort((a, b) => (a.id == rubro ? 0 : 1).compareTo(b.id == rubro ? 0 : 1));
    return [
      for (final principal in ordenadas)
        for (final sub in principal.subcategorias)
          DropdownMenuItem(
            value: sub.id,
            child: Text('${sub.etiqueta}  ·  ${principal.nombre}', overflow: TextOverflow.ellipsis),
          ),
    ];
  }
}

/// "Ganas Bs 70 por cada uno (29 %)", con el precio y lo que le costó.
class _Ganancia extends StatelessWidget {
  const _Ganancia(this.calculo);

  final ({double ganancia, double? porcentaje})? calculo;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final calculo = this.calculo;
    final pierde = calculo != null && calculo.ganancia < 0;
    final fondo = calculo == null ? c.surfaceContainerHighest : (pierde ? c.errorContainer : c.primaryContainer);
    final letra = calculo == null ? c.onSurfaceVariant : (pierde ? c.onErrorContainer : c.onPrimaryContainer);
    final pct = calculo?.porcentaje;

    return Container(
      key: const Key('ganancia'),
      padding: const EdgeInsets.all(AppEspacios.m - 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(pierde ? Icons.trending_down : Icons.trending_up, color: letra),
          const SizedBox(width: AppEspacios.s),
          Expanded(
            child: calculo == null
                ? Text(
                    'Escribe el precio y lo que te costó para ver cuánto ganas.',
                    style: textos.bodyMedium?.copyWith(color: letra),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: pierde ? 'Pierdes ' : 'Ganas '),
                        TextSpan(
                          text: Formato.bs(calculo.ganancia.abs()),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: ' por cada uno${pct == null ? '' : ' (${pct.round()} %)'}'),
                      ],
                    ),
                    style: textos.bodyMedium?.copyWith(color: letra),
                  ),
          ),
        ],
      ),
    );
  }
}
