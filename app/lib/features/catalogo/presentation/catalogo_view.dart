import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/producto.dart';
import 'widgets/tarjetas_catalogo.dart';

/// Inicio del cliente: buscador, categorías, ofertas y la grilla de productos
/// (de 20 en 20, con "Ver más").
class CatalogoView extends ConsumerStatefulWidget {
  const CatalogoView({super.key, this.encabezado});

  /// Algo para mostrar arriba de todo (ej. "¿Tienes un negocio?").
  final Widget? encabezado;

  @override
  ConsumerState<CatalogoView> createState() => _CatalogoViewState();
}

class _CatalogoViewState extends ConsumerState<CatalogoView> {
  final _busqueda = TextEditingController();
  FiltroCatalogo _filtro = filtroInicial;
  final _productos = <Producto>[];
  int _pagina = 0;
  bool _hayMas = false;
  bool _cargando = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar(desdeCero: true);
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool desdeCero = false}) async {
    final filtro = _filtro;
    setState(() {
      _cargando = true;
      _error = null;
      if (desdeCero) {
        _productos.clear();
        _pagina = 0;
      }
    });
    try {
      final pagina = await ref.read(catalogoRepositoryProvider).productos(filtro, pagina: _pagina + 1);
      if (!mounted || filtro != _filtro) return; // cambió el filtro mientras cargaba
      setState(() {
        _productos.addAll(pagina.items);
        _pagina = pagina.pagina;
        _hayMas = pagina.hayMas;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted && filtro == _filtro) setState(() => _cargando = false);
    }
  }

  void _filtrar(FiltroCatalogo filtro) {
    _filtro = filtro;
    _cargar(desdeCero: true);
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoriasProvider).value ?? const [];

    return RefreshIndicator(
      onRefresh: () => _cargar(desdeCero: true),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m, AppEspacios.m, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?widget.encabezado,
                      if (widget.encabezado != null) const SizedBox(height: AppEspacios.m),
                      TextField(
                        key: const Key('buscar-productos'),
                        controller: _busqueda,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Buscar productos o negocios',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _busqueda.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Borrar',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _busqueda.clear();
                                    _filtrar((
                                      categoria: _filtro.categoria,
                                      negocio: null,
                                      texto: null,
                                      soloOfertas: _filtro.soloOfertas,
                                      orden: _filtro.orden,
                                    ));
                                  },
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (texto) => _filtrar((
                          categoria: _filtro.categoria,
                          negocio: null,
                          texto: texto,
                          soloOfertas: _filtro.soloOfertas,
                          orden: _filtro.orden,
                        )),
                      ),
                      const SizedBox(height: AppEspacios.m - 4),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            FilterChip(
                              key: const Key('filtro-ofertas'),
                              label: const Text('🔥 Ofertas'),
                              selected: _filtro.soloOfertas,
                              onSelected: (si) => _filtrar((
                                categoria: _filtro.categoria,
                                negocio: null,
                                texto: _filtro.texto,
                                soloOfertas: si,
                                orden: _filtro.orden,
                              )),
                            ),
                            const SizedBox(width: AppEspacios.s),
                            ChoiceChip(
                              label: const Text('Todo'),
                              selected: _filtro.categoria == null,
                              onSelected: (_) => _filtrar((
                                categoria: null,
                                negocio: null,
                                texto: _filtro.texto,
                                soloOfertas: _filtro.soloOfertas,
                                orden: _filtro.orden,
                              )),
                            ),
                            for (final categoria in categorias) ...[
                              const SizedBox(width: AppEspacios.s),
                              ChoiceChip(
                                label: Text(categoria.etiqueta),
                                selected: _filtro.categoria == categoria.id,
                                onSelected: (_) => _filtrar((
                                  categoria: categoria.id,
                                  negocio: null,
                                  texto: _filtro.texto,
                                  soloOfertas: _filtro.soloOfertas,
                                  orden: _filtro.orden,
                                )),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          tooltip: 'Ordenar',
                          initialValue: _filtro.orden,
                          onSelected: (orden) => _filtrar((
                            categoria: _filtro.categoria,
                            negocio: null,
                            texto: _filtro.texto,
                            soloOfertas: _filtro.soloOfertas,
                            orden: orden,
                          )),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'populares', child: Text('Más vendidos')),
                            PopupMenuItem(value: 'recientes', child: Text('Más nuevos')),
                            PopupMenuItem(value: 'precio', child: Text('Precio: menor a mayor')),
                            PopupMenuItem(value: 'precio_desc', child: Text('Precio: mayor a menor')),
                            PopupMenuItem(value: 'rating', child: Text('Mejor calificados')),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppEspacios.s),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort, size: 18),
                                const SizedBox(width: AppEspacios.xs),
                                Text(_textoOrden(_filtro.orden)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ..._contenido(),
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    if (_productos.isEmpty && _cargando) {
      return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))];
    }
    if (_productos.isEmpty && _error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: VistaError(error: _error!, alReintentar: () => _cargar(desdeCero: true)),
        ),
      ];
    }
    if (_productos.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EstadoVacio(
            icono: Icons.search_off,
            titulo: 'No encontramos productos',
            texto: 'Prueba con otra palabra o categoría.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m),
        sliver: SliverLayoutBuilder(
          builder: (context, limites) {
            // 1100 de ancho máximo menos el margen de 16 a cada lado: igual que el buscador de arriba.
            const maximo = 1100.0 - 2 * AppEspacios.m;
            final ancho = limites.crossAxisExtent.clamp(0, maximo).toDouble();
            final columnas = columnasPara(ancho);
            return SliverCrossAxisConstrained(
              maxCrossAxisExtent: maximo,
              child: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnas,
                  mainAxisSpacing: AppEspacios.m - 4,
                  crossAxisSpacing: AppEspacios.m - 4,
                  // Foto 4:3 + el texto de abajo (más alto si la letra es grande).
                  mainAxisExtent: (ancho - (columnas - 1) * 12) / columnas * 3 / 4 +
                      MediaQuery.textScalerOf(context).scale(122),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => TarjetaProducto(
                    producto: _productos[i],
                    alTocar: () => context.push('/producto/${_productos[i].id}'),
                  ),
                  childCount: _productos.length,
                ),
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.l),
          child: Center(
            child: _cargando
                ? const CircularProgressIndicator()
                : _hayMas
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
                        onPressed: _cargar,
                        child: const Text('Ver más'),
                      )
                    : const SizedBox(height: AppEspacios.xl),
          ),
        ),
      ),
    ];
  }

  String _textoOrden(String orden) => switch (orden) {
        'recientes' => 'Más nuevos',
        'precio' => 'Precio: menor a mayor',
        'precio_desc' => 'Precio: mayor a menor',
        'rating' => 'Mejor calificados',
        _ => 'Más vendidos',
      };
}

/// Limita el ancho de un sliver y lo centra (en PC no se estira de borde a borde).
class SliverCrossAxisConstrained extends StatelessWidget {
  const SliverCrossAxisConstrained({super.key, required this.maxCrossAxisExtent, required this.child});

  final double maxCrossAxisExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, limites) {
        final sobra = (limites.crossAxisExtent - maxCrossAxisExtent).clamp(0, double.infinity) / 2;
        return SliverPadding(padding: EdgeInsets.symmetric(horizontal: sobra.toDouble()), sliver: child);
      },
    );
  }
}
