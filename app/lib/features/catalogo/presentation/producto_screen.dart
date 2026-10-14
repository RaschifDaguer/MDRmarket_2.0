import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../carrito/presentation/agregar_al_carrito.dart';
import '../../carrito/presentation/carrito_controller.dart';
import '../data/catalogo_repository.dart';
import '../domain/producto.dart';
import 'widgets/tarjeta_resena.dart';
import 'widgets/tarjetas_catalogo.dart';

/// Detalle de un producto: fotos, precio, negocio, descripción, reseñas y
/// "Agregar al carrito".
class ProductoScreen extends ConsumerStatefulWidget {
  const ProductoScreen({super.key, required this.productoId});

  final int productoId;

  @override
  ConsumerState<ProductoScreen> createState() => _ProductoScreenState();
}

class _ProductoScreenState extends ConsumerState<ProductoScreen> {
  int _cantidad = 1;
  int _foto = 0;

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(productoDetalleProvider(widget.productoId));
    final carrito = ref.watch(carritoProvider);

    return detalle.when(
      loading: () => const Pantalla(titulo: 'Producto', child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Pantalla(
        titulo: 'Producto',
        child: VistaError(error: e, alReintentar: () => ref.invalidate(productoDetalleProvider(widget.productoId))),
      ),
      data: (d) {
        final p = d.producto;
        final enCarrito = carrito?.cantidadDe(p.id) ?? 0;
        final maximo = p.stock == null ? 99 : (p.stock! - enCarrito).clamp(0, 99);
        final sePuede = !p.agotado && p.negocio.abierto && maximo > 0;
        final fotos = d.imagenes.isEmpty ? <String?>[p.imagenUrl] : d.imagenes;

        return Pantalla(
          titulo: p.nombre,
          acciones: [_BotonCarrito(unidades: carrito?.unidades ?? 0)],
          abajo: Padding(
            padding: const EdgeInsets.all(AppEspacios.m),
            child: Row(
              children: [
                SelectorCantidad(
                  valor: sePuede ? _cantidad.clamp(1, maximo) : 1,
                  maximo: sePuede ? maximo : 1,
                  alCambiar: (n) => setState(() => _cantidad = n),
                ),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  // Sin ícono: así entra "Agregar · Bs 1.250,00" en un celular angosto.
                  child: BotonPrincipal(
                    texto: sePuede
                        ? 'Agregar · ${Formato.bs(p.precioFinal * _cantidad.clamp(1, maximo))}'
                        : (!p.negocio.abierto ? 'Negocio cerrado' : 'Agotado'),
                    onPressed: sePuede
                        ? () async {
                            if (await agregarAlCarrito(context, ref, p, _cantidad.clamp(1, maximo))) {
                              setState(() => _cantidad = 1);
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppEspacios.xl),
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: fotos.length,
                      onPageChanged: (i) => setState(() => _foto = i),
                      itemBuilder: (_, i) => ImagenRed(fotos[i], radio: 0, icono: Icons.shopping_bag_outlined),
                    ),
                    if (p.enOferta)
                      Positioned(top: AppEspacios.m, left: AppEspacios.m, child: EtiquetaDescuento(p.descuentoPct)),
                    if (fotos.length > 1)
                      Positioned(
                        bottom: AppEspacios.s,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < fotos.length; i++)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _foto ? Colors.white : Colors.white54,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppEspacios.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppEspacios.xs),
                    PrecioProducto(precio: p.precio, precioFinal: p.precioFinal, grande: true),
                    const SizedBox(height: AppEspacios.xs),
                    Wrap(
                      spacing: AppEspacios.m,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Calificacion(promedio: p.rating, total: p.totalResenas),
                        if (p.stock != null && p.stock! > 0 && p.stock! <= 5)
                          Text('¡Quedan ${p.stock}!', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        if (enCarrito > 0) Text('Tienes $enCarrito en el carrito'),
                      ],
                    ),
                    const SizedBox(height: AppEspacios.m),
                    _TarjetaNegocio(producto: p, pedidoMinimo: d.pedidoMinimo, tiempo: d.tiempoPreparacionMin),
                    if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: AppEspacios.m),
                      Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppEspacios.xs),
                      Text(p.descripcion!),
                    ],
                    const SizedBox(height: AppEspacios.l),
                    Text('Reseñas', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppEspacios.s),
                    if (d.resenas.isEmpty)
                      const Text('Todavía nadie lo calificó.')
                    else
                      for (final r in d.resenas) ...[TarjetaResena(resena: r), const SizedBox(height: AppEspacios.s)],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TarjetaNegocio extends StatelessWidget {
  const _TarjetaNegocio({required this.producto, required this.pedidoMinimo, this.tiempo});

  final Producto producto;
  final double pedidoMinimo;
  final int? tiempo;

  @override
  Widget build(BuildContext context) {
    final negocio = producto.negocio;
    final textos = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        onTap: () => context.push('/tienda/${negocio.id}'),
        leading: ImagenRed(negocio.logoUrl, ancho: 48, alto: 48, radio: 12, icono: Icons.storefront),
        title: Text(negocio.nombre),
        subtitle: Wrap(
          spacing: AppEspacios.m - 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EtiquetaAbierto(abierto: negocio.abierto),
            if (tiempo != null) Text('~$tiempo min', style: textos.bodySmall),
            if (pedidoMinimo > 0) Text('Mínimo ${Formato.bs(pedidoMinimo)}', style: textos.bodySmall),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Ícono del carrito con la cantidad de unidades.
class _BotonCarrito extends StatelessWidget {
  const _BotonCarrito({required this.unidades});

  final int unidades;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Carrito',
      onPressed: () => context.push('/carrito'),
      icon: Badge(
        isLabelVisible: unidades > 0,
        label: Text('$unidades'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
