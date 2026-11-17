import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/data/pedidos_repository.dart';
import '../data/catalogo_repository.dart';
import '../domain/tienda.dart';
import 'widgets/tarjetas_catalogo.dart';

/// Pantalla "Tiendas" (desde el Inicio): negocios aprobados, abiertos
/// primero, con buscador y rubros. Con la dirección del cliente, cada una
/// muestra el tiempo y el envío.
class TiendasScreen extends StatelessWidget {
  const TiendasScreen({super.key});

  @override
  Widget build(BuildContext context) => const Pantalla(titulo: 'Tiendas', child: TiendasView());
}

/// Lista de tiendas con buscador y rubros.
class TiendasView extends ConsumerStatefulWidget {
  const TiendasView({super.key});

  @override
  ConsumerState<TiendasView> createState() => _TiendasViewState();
}

class _TiendasViewState extends ConsumerState<TiendasView> {
  final _busqueda = TextEditingController();
  final _tiendas = <Tienda>[];
  int _pagina = 0;
  int? _categoria;
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
    setState(() {
      _cargando = true;
      _error = null;
      if (desdeCero) {
        _tiendas.clear();
        _pagina = 0;
      }
    });
    try {
      // Sin dirección guardada se listan igual, sin envío ni tiempo.
      final entrega = await ref.read(entregaClienteProvider.future).catchError((_) => null);
      final pagina = await ref
          .read(catalogoRepositoryProvider)
          .tiendas(texto: _busqueda.text, categoria: _categoria, pagina: _pagina + 1, ubicacion: entrega?.ubicacion);
      if (!mounted) return;
      setState(() {
        _tiendas.addAll(pagina.items);
        _pagina = pagina.pagina;
        _hayMas = pagina.hayMas;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrar(int? categoria) {
    setState(() => _categoria = categoria);
    _cargar(desdeCero: true);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _cargar(desdeCero: true),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _busqueda,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(hintText: 'Buscar un negocio', prefixIcon: Icon(Icons.search)),
                    onSubmitted: (_) => _cargar(desdeCero: true),
                  ),
                  const SizedBox(height: AppEspacios.s),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _categoria == null,
                          onSelected: (_) => _filtrar(null),
                        ),
                        for (final categoria in ref.watch(categoriasProvider).value ?? const []) ...[
                          const SizedBox(width: AppEspacios.s),
                          ChoiceChip(
                            key: Key('rubro-${categoria.id}'),
                            label: Text(categoria.etiqueta),
                            selected: _categoria == categoria.id,
                            onSelected: (_) => _filtrar(categoria.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppEspacios.m),
                  if (_tiendas.isEmpty && _cargando)
                    const Padding(
                      padding: EdgeInsets.all(AppEspacios.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_tiendas.isEmpty && _error != null)
                    VistaError(error: _error!, alReintentar: () => _cargar(desdeCero: true))
                  else if (_tiendas.isEmpty)
                    const EstadoVacio(icono: Icons.storefront_outlined, titulo: 'No hay negocios con ese nombre')
                  else ...[
                    for (final (i, tienda) in _tiendas.indexed) ...[
                      Aparecer(
                        orden: i.clamp(0, 8),
                        child: TarjetaTienda(tienda: tienda, alTocar: () => context.push('/tienda/${tienda.id}')),
                      ),
                      const SizedBox(height: AppEspacios.m - 4),
                    ],
                    if (_hayMas)
                      Center(
                        child: _cargando
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
                                onPressed: _cargar,
                                child: const Text('Ver más'),
                              ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
