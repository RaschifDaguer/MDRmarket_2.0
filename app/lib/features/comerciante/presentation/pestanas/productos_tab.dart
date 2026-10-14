import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/mi_negocio_repository.dart';
import '../../domain/mi_producto.dart';
import '../../domain/negocio.dart';

/// Mis productos: lista, mostrar/ocultar y "Agregar producto".
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
          final filtrados = _busqueda.isEmpty
              ? lista
              : lista.where((p) => p.nombre.toLowerCase().contains(_busqueda.toLowerCase())).toList();
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
                          texto: 'Agrega el primero: nombre, precio y una foto.',
                        )
                      else ...[
                        if (lista.length > 6) ...[
                          TextField(
                            decoration: const InputDecoration(hintText: 'Buscar en mis productos', prefixIcon: Icon(Icons.search)),
                            onChanged: (v) => setState(() => _busqueda = v.trim()),
                          ),
                          const SizedBox(height: AppEspacios.m - 4),
                        ],
                        Text(
                          '${lista.where((p) => p.disponible).length} visibles de ${lista.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppEspacios.s),
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

class _FilaProducto extends ConsumerStatefulWidget {
  const _FilaProducto({required this.negocioId, required this.producto});

  final int negocioId;
  final MiProducto producto;

  @override
  ConsumerState<_FilaProducto> createState() => _FilaProductoState();
}

class _FilaProductoState extends ConsumerState<_FilaProducto> {
  bool? _disponible; // cambio en curso (se muestra antes de que responda la API)

  Future<void> _mostrar(bool disponible) async {
    setState(() => _disponible = disponible);
    try {
      await ref.read(miNegocioRepositoryProvider).disponible(widget.negocioId, widget.producto.id, disponible);
      ref.invalidate(misProductosProvider(widget.negocioId));
      ref.invalidate(resumenNegocioProvider(widget.negocioId));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _disponible = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
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
        child: InkWell(
          key: Key('mi-producto-${p.id}'),
          onTap: () => context.push('/negocio/producto', extra: p),
          child: Opacity(
            opacity: visible ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.all(AppEspacios.m - 4),
              child: Row(
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
                          p.stock == null ? 'Sin control de stock' : (p.sinStock ? 'Sin stock' : 'Stock: ${p.stock}'),
                          style: textos.bodySmall?.copyWith(color: p.sinStock ? c.error : c.onSurfaceVariant),
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
            ),
          ),
        ),
      ),
    );
  }
}
