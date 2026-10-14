import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/tienda.dart';
import 'widgets/tarjeta_resena.dart';
import 'widgets/tarjetas_catalogo.dart';

/// Página de un negocio: datos, horario, sus productos y reseñas.
class TiendaScreen extends ConsumerWidget {
  const TiendaScreen({super.key, required this.tiendaId});

  final int tiendaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(tiendaDetalleProvider(tiendaId));

    return detalle.when(
      loading: () => const Pantalla(titulo: 'Negocio', child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Pantalla(
        titulo: 'Negocio',
        child: VistaError(error: e, alReintentar: () => ref.invalidate(tiendaDetalleProvider(tiendaId))),
      ),
      data: (d) => Pantalla(
        titulo: d.tienda.nombre,
        anchoMaximo: 1100,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(tiendaDetalleProvider(tiendaId).future),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppEspacios.m),
                sliver: SliverToBoxAdapter(child: _Cabecera(tienda: d.tienda)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m),
                sliver: SliverToBoxAdapter(
                  child: Text('Productos (${d.productos.length})', style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              if (d.productos.isEmpty)
                const SliverToBoxAdapter(
                  child: EstadoVacio(icono: Icons.inventory_2_outlined, titulo: 'Todavía no tiene productos'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppEspacios.m),
                  sliver: SliverLayoutBuilder(builder: (context, limites) {
                    final columnas = columnasPara(limites.crossAxisExtent);
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnas,
                        mainAxisSpacing: AppEspacios.m - 4,
                        crossAxisSpacing: AppEspacios.m - 4,
                        mainAxisExtent: (limites.crossAxisExtent - (columnas - 1) * 12) / columnas * 3 / 4 +
                            MediaQuery.textScalerOf(context).scale(104),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => TarjetaProducto(
                          producto: d.productos[i],
                          mostrarNegocio: false,
                          alTocar: () => context.push('/producto/${d.productos[i].id}'),
                        ),
                        childCount: d.productos.length,
                      ),
                    );
                  }),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.s, AppEspacios.m, AppEspacios.xl),
                sliver: SliverList.list(children: [
                  Text('Reseñas (${d.tienda.totalResenas})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppEspacios.s),
                  if (d.resenas.isEmpty) const Text('Todavía nadie lo calificó.'),
                  for (final r in d.resenas) ...[TarjetaResena(resena: r), const SizedBox(height: AppEspacios.s)],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.tienda});

  final Tienda tienda;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Tarjeta3D(
      inclinacionMax: 3,
      padding: const EdgeInsets.all(AppEspacios.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ImagenRed(tienda.logoUrl, ancho: 84, alto: 84, radio: 20, icono: Icons.storefront),
              const SizedBox(width: AppEspacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tienda.nombre, style: textos.titleLarge),
                    if (tienda.categoria != null)
                      Text([?tienda.categoriaIcono, tienda.categoria!].join(' '), style: textos.bodyMedium),
                    const SizedBox(height: AppEspacios.xs),
                    Wrap(
                      spacing: AppEspacios.m - 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Calificacion(promedio: tienda.rating, total: tienda.totalResenas),
                        EtiquetaAbierto(abierto: tienda.abierto),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tienda.descripcion != null && tienda.descripcion!.isNotEmpty) ...[
            const SizedBox(height: AppEspacios.m - 4),
            Text(tienda.descripcion!),
          ],
          const SizedBox(height: AppEspacios.m - 4),
          Wrap(
            spacing: AppEspacios.m,
            runSpacing: AppEspacios.xs,
            children: [
              if (tienda.direccion != null) _Dato(icono: Icons.place_outlined, texto: tienda.direccion!),
              if (tienda.tiempoPreparacionMin != null)
                _Dato(icono: Icons.timer_outlined, texto: 'Prepara en ~${tienda.tiempoPreparacionMin} min'),
              if (tienda.pedidoMinimo > 0)
                _Dato(icono: Icons.shopping_basket_outlined, texto: 'Pedido mínimo ${Formato.bs(tienda.pedidoMinimo)}'),
              if (tienda.telefono != null) _Dato(icono: Icons.phone_outlined, texto: tienda.telefono!),
            ],
          ),
          if (tienda.horarios.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              // La tarjeta 3D no es "Material": sin esto el efecto al tocar no se ve.
              child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule, color: c.primary),
                  title: const Text('Horario de atención'),
                  children: [
                    for (final h in tienda.horarios)
                      ListTile(dense: true, title: Text(h.dia), trailing: Text('${h.apertura} – ${h.cierre}')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}
