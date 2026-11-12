import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/mi_negocio_repository.dart';
import '../../domain/mi_producto.dart';
import '../../domain/negocio.dart';

/// Mis productos: cuántos hay y cuánto stock, los agotados primero (con
/// "Renovar stock"), mostrar/ocultar y "Agregar producto".
class ProductosTab extends ConsumerStatefulWidget {
  const ProductosTab({super.key, required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends ConsumerState<ProductosTab> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(misProductosProvider(widget.negocio.id));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(misProductosProvider(widget.negocio.id).future),
      child: productos.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [VistaError(error: e, alReintentar: () => ref.invalidate(misProductosProvider(widget.negocio.id)))],
        ),
        data: (lista) {
          final filtrados = (_busqueda.isEmpty
                  ? [...lista]
                  : lista.where((p) => p.nombre.toLowerCase().contains(_busqueda.toLowerCase())).toList())
            // Los agotados arriba: son los que hay que renovar.
            ..sort((a, b) => (b.sinStock ? 1 : 0) - (a.sinStock ? 1 : 0));
          final agotados = lista.where((p) => p.sinStock).length;
          final unidades = lista.fold<int>(0, (total, p) => total + (p.stock ?? 0));

          return ListView(
            padding: const EdgeInsets.all(AppEspacios.m),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BotonPrincipal(
                        key: const Key('nuevo-producto'),
                        texto: 'Agregar producto',
                        icono: Icons.add,
                        onPressed: () => context.push('/negocio/producto'),
                      ),
                      const SizedBox(height: AppEspacios.m),
                      if (lista.isEmpty)
                        const EstadoVacio(
                          icono: Icons.inventory_2_outlined,
                          titulo: 'Todavía no tienes productos',
                          texto: 'Agrega el primero: nombre, precio, cuántas unidades tienes y una foto.',
                        )
                      else ...[
                        _Inventario(productos: lista.length, unidades: unidades, agotados: agotados,
                            visibles: lista.where((p) => p.disponible).length),
                        const SizedBox(height: AppEspacios.m - 4),
                        if (lista.length > 6) ...[
                          TextField(
                            decoration: const InputDecoration(hintText: 'Buscar en mis productos', prefixIcon: Icon(Icons.search)),
                            onChanged: (v) => setState(() => _busqueda = v.trim()),
                          ),
                          const SizedBox(height: AppEspacios.m - 4),
                        ],
                        for (final p in filtrados) _FilaProducto(negocioId: widget.negocio.id, producto: p),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Cuántos productos hay, cuántas unidades en stock y cuántos se agotaron.
class _Inventario extends StatelessWidget {
  const _Inventario({required this.productos, required this.unidades, required this.agotados, required this.visibles});

  final int productos;
  final int unidades;
  final int agotados;
  final int visibles;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    Widget dato(String valor, String texto, {bool alerta = false}) => Expanded(
          child: Column(
            children: [
              Text(valor, style: textos.titleLarge?.copyWith(color: alerta ? c.error : null)),
              Text(texto, style: textos.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );

    return Card(
      key: const Key('inventario'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppEspacios.m - 4, horizontal: AppEspacios.s),
        child: Column(
          children: [
            Row(
              children: [
                dato('$productos', productos == 1 ? 'producto' : 'productos'),
                dato('$unidades', 'unidades en stock'),
                dato('$agotados', agotados == 1 ? 'agotado' : 'agotados', alerta: agotados > 0),
              ],
            ),
            const SizedBox(height: AppEspacios.xs),
            Text('$visibles visibles en el catálogo', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _FilaProducto extends ConsumerStatefulWidget {
  const _FilaProducto({required this.negocioId, required this.producto});

  final int negocioId;
  final MiProducto producto;

  @override
  ConsumerState<_FilaProducto> createState() => _FilaProductoState();
}

class _FilaProductoState extends ConsumerState<_FilaProducto> {
  bool? _disponible; // cambio en curso (se muestra antes de que responda la API)

  void _refrescar() {
    ref.invalidate(misProductosProvider(widget.negocioId));
    ref.invalidate(resumenNegocioProvider(widget.negocioId));
  }

  Future<void> _mostrar(bool disponible) async {
    setState(() => _disponible = disponible);
    try {
      await ref.read(miNegocioRepositoryProvider).disponible(widget.negocioId, widget.producto.id, disponible);
      _refrescar();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _disponible = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  /// "Renovar stock": cuántas unidades hay ahora.
  Future<void> _renovar() async {
    final p = widget.producto;
    final control = TextEditingController(text: (p.stock ?? 0) > 0 ? '${p.stock}' : '');
    final mensajero = ScaffoldMessenger.of(context);
    final unidades = await showDialog<int>(
      context: context,
      builder: (contexto) {
        String? error;
        return StatefulBuilder(
          builder: (contexto, cambiar) => AlertDialog(
            title: Text('Renovar «${p.nombre}»'),
            content: TextField(
              key: const Key('campo-renovar'),
              controller: control,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: '¿Cuántas unidades tienes ahora?', suffixText: 'unidades', errorText: error),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
              FilledButton(
                key: const Key('guardar-renovar'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () {
                  final n = int.tryParse(control.text.trim());
                  if (n == null || n < 1) {
                    cambiar(() => error = 'Escribe 1 o más');
                    return;
                  }
                  Navigator.pop(contexto, n);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
    control.dispose();
    if (unidades == null) return;

    try {
      await ref.read(miNegocioRepositoryProvider).renovarStock(widget.negocioId, p.id, unidades);
      _refrescar();
      mensajero.showSnackBar(SnackBar(content: Text('«${p.nombre}»: $unidades unidades en stock')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.errorDe('stock') ?? e.mensaje)));
    }
  }

  @override
  void didUpdateWidget(covariant _FilaProducto anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.producto != widget.producto) _disponible = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final visible = _disponible ?? p.disponible;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacios.s),
      child: Card(
        // Agotado: borde rojo para que salte a la vista.
        shape: p.sinStock
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.error, width: 1.5))
            : null,
        child: InkWell(
          key: Key('mi-producto-${p.id}'),
          onTap: () => context.push('/negocio/producto', extra: p),
          child: Opacity(
            opacity: visible ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.all(AppEspacios.m - 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      ImagenRed(p.imagenUrl, ancho: 60, alto: 60, radio: 12, icono: Icons.shopping_bag_outlined),
                      const SizedBox(width: AppEspacios.m - 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nombre, style: textos.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Wrap(
                              spacing: AppEspacios.s,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(Formato.bs(p.precioVigente),
                                    style: textos.bodyMedium?.copyWith(color: p.enOferta ? c.error : null, fontWeight: FontWeight.w600)),
                                if (p.enOferta)
                                  Text(Formato.bs(p.precio),
                                      style: textos.bodySmall?.copyWith(decoration: TextDecoration.lineThrough)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              switch (p.stock) {
                                null => 'Sin stock definido: renuévalo para ponerlo',
                                final n when n <= 0 => 'Agotado · stock insuficiente',
                                final n => '$n ${n == 1 ? 'unidad' : 'unidades'} en stock',
                              },
                              style: textos.bodySmall?.copyWith(
                                color: p.sinStock ? c.error : c.onSurfaceVariant,
                                fontWeight: p.sinStock ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Switch(value: visible, onChanged: _mostrar),
                          Text(visible ? 'Visible' : 'Oculto', style: textos.labelSmall),
                        ],
                      ),
                    ],
                  ),
                  if (p.sinStock || p.stock == null) ...[
                    const SizedBox(height: AppEspacios.s),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: Key('renovar-${p.id}'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: _renovar,
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: const Text('Renovar stock'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
