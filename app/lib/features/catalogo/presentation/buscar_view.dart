import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/preferencias.dart';
import '../../../core/theme/app_colores.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/producto.dart';
import 'widgets/tarjetas_catalogo.dart';

/// Con esta cantidad o menos se muestra "Quedan N" (igual que el umbral de la tienda).
const _pocoStock = 5;

/// Pantalla de búsqueda abierta desde una categoría del Inicio.
class BuscarScreen extends StatelessWidget {
  const BuscarScreen({super.key, this.categoria});

  final int? categoria;

  @override
  Widget build(BuildContext context) => Pantalla(
    titulo: 'Buscar',
    child: BuscarView(categoria: categoria),
  );
}

/// Pestaña "Buscar": busca mientras escribes, con filtros (oferta, abierto
/// ahora, orden), búsquedas recientes y resultados agrupados por tienda.
class BuscarView extends ConsumerStatefulWidget {
  const BuscarView({super.key, this.categoria});

  final int? categoria;

  @override
  ConsumerState<BuscarView> createState() => _BuscarViewState();
}

class _BuscarViewState extends ConsumerState<BuscarView> {
  final _texto = TextEditingController();
  Timer? _espera;
  late FiltroCatalogo _filtro = (
    categoria: widget.categoria,
    negocio: null,
    texto: null,
    soloOfertas: false,
    orden: 'populares',
  );
  bool _soloAbiertos = false;
  final _productos = <Producto>[];
  int _pagina = 0;
  bool _hayMas = false;
  bool _cargando = false;
  Object? _error;

  /// Sin texto ni categoría se muestran las búsquedas recientes en vez de resultados.
  bool get _buscando => (_filtro.texto?.trim().isNotEmpty ?? false) || _filtro.categoria != null || _filtro.soloOfertas;

  @override
  void initState() {
    super.initState();
    if (_buscando) _cargar(desdeCero: true);
  }

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
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
      if (!mounted || filtro != _filtro) return;
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

  void _filtrar({String? texto, bool? soloOfertas, String? orden, bool limpiarTexto = false}) {
    _filtro = (
      categoria: _filtro.categoria,
      negocio: null,
      texto: limpiarTexto ? null : (texto ?? _filtro.texto),
      soloOfertas: soloOfertas ?? _filtro.soloOfertas,
      orden: orden ?? _filtro.orden,
    );
    if (_buscando) {
      _cargar(desdeCero: true);
    } else {
      setState(_productos.clear);
    }
  }

  /// Busca mientras escribe, sin pedirle a la API una consulta por letra.
  void _alEscribir(String texto) {
    setState(() {});
    _espera?.cancel();
    _espera = Timer(
      const Duration(milliseconds: 400),
      () => _filtrar(texto: texto, limpiarTexto: texto.trim().isEmpty),
    );
  }

  void _buscarYa(String texto) {
    _espera?.cancel();
    ref.read(busquedasRecientesProvider.notifier).agregar(texto);
    _filtrar(texto: texto, limpiarTexto: texto.trim().isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _soloAbiertos ? _productos.where((p) => p.negocio.abierto).toList() : _productos;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: () => _cargar(desdeCero: true),
            child: ListView(
              padding: const EdgeInsets.all(AppEspacios.m),
              children: [
                TextField(
                  key: const Key('campo-buscar'),
                  controller: _texto,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Busca productos o tiendas',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _texto.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _texto.clear();
                              _buscarYa('');
                            },
                          ),
                  ),
                  onChanged: _alEscribir,
                  onSubmitted: _buscarYa,
                ),
                const SizedBox(height: AppEspacios.s + 2),
                _filtros(),
                const SizedBox(height: AppEspacios.m),
                if (!_buscando) ..._recientes() else ..._resultados(visibles),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtros() {
    return Wrap(
      spacing: AppEspacios.s,
      runSpacing: AppEspacios.xs,
      children: [
        PopupMenuButton<String>(
          tooltip: 'Ordenar',
          initialValue: _filtro.orden,
          onSelected: (orden) => _filtrar(orden: orden),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'populares', child: Text('Más vendidos')),
            PopupMenuItem(value: 'recientes', child: Text('Más nuevos')),
            PopupMenuItem(value: 'precio', child: Text('Precio: menor a mayor')),
            PopupMenuItem(value: 'precio_desc', child: Text('Precio: mayor a menor')),
            PopupMenuItem(value: 'rating', child: Text('Mejor calificados')),
          ],
          child: Chip(avatar: const Icon(Icons.sort, size: 18), label: Text(_textoOrden(_filtro.orden))),
        ),
        FilterChip(
          key: const Key('filtro-oferta'),
          label: const Text('Con oferta'),
          selected: _filtro.soloOfertas,
          onSelected: (si) => _filtrar(soloOfertas: si),
        ),
        FilterChip(
          key: const Key('filtro-abierto'),
          label: const Text('Abierto ahora'),
          selected: _soloAbiertos,
          onSelected: (si) => setState(() => _soloAbiertos = si),
        ),
      ],
    );
  }

  List<Widget> _recientes() {
    final recientes = ref.watch(busquedasRecientesProvider);
    final textos = Theme.of(context).textTheme;
    if (recientes.isEmpty) {
      return const [
        EstadoVacio(
          icono: Icons.search_rounded,
          titulo: '¿Qué buscas hoy?',
          texto: 'Escribe un producto o el nombre de una tienda.',
        ),
      ];
    }
    return [
      Row(
        children: [
          Expanded(
            child: Text('Búsquedas recientes', style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => ref.read(busquedasRecientesProvider.notifier).borrar(),
            child: const Text('Borrar'),
          ),
        ],
      ),
      Wrap(
        spacing: AppEspacios.s,
        runSpacing: AppEspacios.s,
        children: [
          for (final busqueda in recientes)
            ActionChip(
              key: Key('reciente-$busqueda'),
              avatar: const Icon(Icons.history, size: 18),
              label: Text(busqueda),
              onPressed: () {
                _texto.text = busqueda;
                _buscarYa(busqueda);
              },
            ),
        ],
      ),
    ];
  }

  List<Widget> _resultados(List<Producto> visibles) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    if (visibles.isEmpty && _cargando) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppEspacios.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (visibles.isEmpty && _error != null) {
      return [VistaError(error: _error!, alReintentar: () => _cargar(desdeCero: true))];
    }
    if (visibles.isEmpty) {
      return const [
        EstadoVacio(
          icono: Icons.search_off,
          titulo: 'No encontramos productos',
          texto: 'Prueba con otra palabra o quita un filtro.',
        ),
      ];
    }

    // "12 resultados en 3 tiendas" y la tienda con más resultados.
    final porTienda = <int, List<Producto>>{};
    for (final p in visibles) {
      porTienda.putIfAbsent(p.negocio.id, () => []).add(p);
    }
    final masResultados = porTienda.values.reduce((a, b) => b.length > a.length ? b : a);
    final n = visibles.length;

    return [
      Text.rich(
        key: const Key('resumen-busqueda'),
        TextSpan(
          children: [
            TextSpan(
              text: '$n ${n == 1 ? 'resultado' : 'resultados'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: ' en ${porTienda.length} ${porTienda.length == 1 ? 'tienda' : 'tiendas'}',
              style: TextStyle(color: c.onSurfaceVariant),
            ),
          ],
        ),
        style: textos.bodyMedium,
      ),
      const SizedBox(height: AppEspacios.s),
      for (final (i, producto) in visibles.indexed) ...[
        Aparecer(
          orden: i.clamp(0, 8),
          child: _FilaResultado(producto: producto),
        ),
        // Después del tercer resultado: la tienda con más coincidencias.
        if (i == 2 && masResultados.length >= 3) _SugerenciaTienda(productos: masResultados),
      ],
      if (_hayMas)
        Padding(
          padding: const EdgeInsets.all(AppEspacios.m),
          child: Center(
            child: _cargando
                ? const CircularProgressIndicator()
                : OutlinedButton(onPressed: _cargar, child: const Text('Ver más')),
          ),
        ),
    ];
  }

  String _textoOrden(String orden) => switch (orden) {
    'recientes' => 'Más nuevos',
    'precio' => 'Menor precio',
    'precio_desc' => 'Mayor precio',
    'rating' => 'Mejor calificados',
    _ => 'Más vendidos',
  };
}

/// Un producto en la lista de resultados.
class _FilaResultado extends StatelessWidget {
  const _FilaResultado({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final stock = producto.stock;

    return Card(
      margin: const EdgeInsets.only(bottom: AppEspacios.s + 2),
      child: InkWell(
        key: Key('resultado-${producto.id}'),
        onTap: () => context.push('/producto/${producto.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.s + 2),
          child: Row(
            children: [
              ImagenRed(producto.imagenUrl, ancho: 64, alto: 64, icono: Icons.inventory_2_outlined),
              const SizedBox(width: AppEspacios.s + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producto.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: textos.titleSmall),
                    Text(
                      [producto.negocio.nombre, if (!producto.negocio.abierto) 'Cerrado'].join(' · '),
                      style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppEspacios.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PrecioProducto(precio: producto.precio, precioFinal: producto.precioFinal),
                        if (producto.enOferta && producto.descuentoPct > 0) EtiquetaDescuento(producto.descuentoPct),
                        if (producto.rating != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 15, color: AppColores.ambar),
                              Text(producto.rating!.toStringAsFixed(1), style: textos.bodySmall),
                            ],
                          ),
                        if (stock != null && stock > 0 && stock <= _pocoStock)
                          Text(
                            'Quedan $stock',
                            style: textos.bodySmall?.copyWith(
                              color: AppColores.ambarTexto,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (producto.agotado) Text('Agotado', style: textos.bodySmall?.copyWith(color: c.error)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "TechStore SCZ tiene 8 productos de esto · Ver tienda".
class _SugerenciaTienda extends StatelessWidget {
  const _SugerenciaTienda({required this.productos});

  final List<Producto> productos;

  @override
  Widget build(BuildContext context) {
    final negocio = productos.first.negocio;
    final c = Theme.of(context).colorScheme;
    return Card(
      color: c.secondaryContainer,
      margin: const EdgeInsets.only(bottom: AppEspacios.s + 2),
      child: ListTile(
        key: const Key('sugerencia-tienda'),
        leading: ImagenRed(negocio.logoUrl, ancho: 40, alto: 40, icono: Icons.storefront),
        title: Text(negocio.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Tiene ${productos.length} productos de esta búsqueda'),
        trailing: TextButton(onPressed: () => context.push('/tienda/${negocio.id}'), child: const Text('Ver tienda')),
      ),
    );
  }
}
