import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/tienda.dart';
import 'widgets/tarjetas_catalogo.dart';

/// Pestaña "Tiendas": negocios aprobados, abiertos primero, con buscador.
class TiendasView extends ConsumerStatefulWidget {
  const TiendasView({super.key});

  @override
  ConsumerState<TiendasView> createState() => _TiendasViewState();
}

class _TiendasViewState extends ConsumerState<TiendasView> {
  final _busqueda = TextEditingController();
  final _tiendas = <Tienda>[];
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
    setState(() {
      _cargando = true;
      _error = null;
      if (desdeCero) {
        _tiendas.clear();
        _pagina = 0;
      }
    });
    try {
      final pagina = await ref.read(catalogoRepositoryProvider).tiendas(texto: _busqueda.text, pagina: _pagina + 1);
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
                  const SizedBox(height: AppEspacios.m),
                  if (_tiendas.isEmpty && _cargando)
                    const Padding(padding: EdgeInsets.all(AppEspacios.xl), child: Center(child: CircularProgressIndicator()))
                  else if (_tiendas.isEmpty && _error != null)
                    VistaError(error: _error!, alReintentar: () => _cargar(desdeCero: true))
                  else if (_tiendas.isEmpty)
                    const EstadoVacio(icono: Icons.storefront_outlined, titulo: 'No hay negocios con ese nombre')
                  else ...[
                    for (final tienda in _tiendas) ...[
                      TarjetaTienda(tienda: tienda, alTocar: () => context.push('/tienda/${tienda.id}')),
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
