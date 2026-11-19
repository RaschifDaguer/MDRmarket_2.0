import 'package:flutter/material.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/producto.dart';
import '../../domain/tienda.dart';

/// Precio de un producto: si está en oferta, el normal tachado al lado.
class PrecioProducto extends StatelessWidget {
  const PrecioProducto({super.key, required this.precio, required this.precioFinal, this.grande = false});

  final double precio;
  final double precioFinal;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final oferta = precioFinal < precio;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppEspacios.s,
      children: [
        Text(
          Formato.bs(precioFinal),
          style: (grande ? textos.headlineSmall : textos.titleMedium)?.copyWith(
            color: oferta ? c.error : c.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (oferta)
          Text(
            Formato.bs(precio),
            style: (grande ? textos.bodyLarge : textos.bodySmall)?.copyWith(
              color: c.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

/// Etiqueta roja "-20%".
class EtiquetaDescuento extends StatelessWidget {
  const EtiquetaDescuento(this.porcentaje, {super.key});

  final int porcentaje;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppEspacios.s, vertical: 2),
      decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(8)),
      child: Text(
        '-$porcentaje%',
        style: TextStyle(color: c.onError, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Etiqueta oscura "+18": bebidas alcohólicas (solo mayores de edad).
class EtiquetaMayores extends StatelessWidget {
  const EtiquetaMayores({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Solo para mayores de 18 años',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppEspacios.s, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white70),
        ),
        child: const Text('+18', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }
}

/// Aviso de productos para mayores de 18: bebidas alcohólicas y tabaco
/// (detalle del producto y confirmar pedido).
class AvisoSoloMayores extends StatelessWidget {
  const AvisoSoloMayores({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Container(
      key: const Key('aviso-mayores'),
      padding: const EdgeInsets.all(AppEspacios.m),
      decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.no_drinks_outlined, color: c.onErrorContainer),
          const SizedBox(width: AppEspacios.s + 2),
          Expanded(
            child: Text(
              'VENTA PROHIBIDA A MENORES DE 18 AÑOS (Leyes 259 y 1280). Al recibir, el repartidor te pedirá tu '
              'carnet; si no lo muestras, no entregará el pedido. El consumo excesivo de alcohol y el consumo de '
              'tabaco son dañinos para la salud.',
              style: textos.bodySmall?.copyWith(color: c.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Producto en la grilla del catálogo.
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({
    super.key,
    required this.producto,
    required this.alTocar,
    this.mostrarNegocio = true,
    this.prefijoClave = 'producto',
  });

  final Producto producto;
  final VoidCallback alTocar;
  final bool mostrarNegocio;

  /// Para no repetir la clave si el producto sale dos veces (ej. en "Ofertas del día").
  final String prefijoClave;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final noDisponible = producto.agotado || !producto.negocio.abierto;

    return Card(
      child: InkWell(
        key: Key('$prefijoClave-${producto.id}'),
        onTap: alTocar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImagenRed(producto.imagenUrl, radio: 0, icono: Icons.shopping_bag_outlined),
                  if (producto.enOferta)
                    Positioned(
                      top: AppEspacios.s,
                      left: AppEspacios.s,
                      child: EtiquetaDescuento(producto.descuentoPct),
                    ),
                  if (producto.soloMayores)
                    const Positioned(top: AppEspacios.s, right: AppEspacios.s, child: EtiquetaMayores()),
                  if (noDisponible)
                    Positioned.fill(
                      child: ColoredBox(
                        color: c.surface.withValues(alpha: 0.65),
                        child: Center(
                          child: Chip(
                            label: Text(producto.agotado ? 'Agotado' : 'Cerrado ahora'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // El texto ocupa el alto que queda en la celda de la grilla; si no
            // alcanza (letra grande, nombre largo), el nombre se recorta.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppEspacios.m - 4, AppEspacios.s, AppEspacios.m - 4, AppEspacios.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        producto.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textos.titleSmall,
                      ),
                    ),
                    if (mostrarNegocio)
                      Text(
                        producto.negocio.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    const SizedBox(height: AppEspacios.xs),
                    PrecioProducto(precio: producto.precio, precioFinal: producto.precioFinal),
                    Calificacion(promedio: producto.rating, total: producto.totalResenas, compacto: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Negocio en la lista de tiendas.
class TarjetaTienda extends StatelessWidget {
  const TarjetaTienda({super.key, required this.tienda, required this.alTocar});

  final Tienda tienda;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        key: Key('tienda-${tienda.id}'),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.m - 4),
          child: Row(
            children: [
              ImagenRed(tienda.logoUrl, ancho: 72, alto: 72, icono: Icons.storefront),
              const SizedBox(width: AppEspacios.m - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tienda.nombre, style: textos.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (tienda.categoria != null)
                      Text(
                        [if (tienda.categoriaIcono != null) tienda.categoriaIcono!, tienda.categoria!].join(' '),
                        style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    const SizedBox(height: AppEspacios.xs),
                    Wrap(
                      spacing: AppEspacios.m - 4,
                      runSpacing: AppEspacios.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Calificacion(promedio: tienda.rating, total: tienda.totalResenas, compacto: true),
                        EtiquetaAbierto(abierto: tienda.abierto),
                        // Con la dirección del cliente: "15–25 min · Envío Bs 3".
                        if (tienda.envio case final envio? when envio.enCobertura) ...[
                          Text(envio.tiempoTexto!, key: Key('tiempo-tienda-${tienda.id}'), style: textos.bodySmall),
                          Text('Envío ${Formato.bs(envio.costoEnvio)}', style: textos.bodySmall),
                        ] else if (tienda.envio != null)
                          Text('Fuera de tu zona', style: textos.bodySmall?.copyWith(color: c.error))
                        else if (tienda.tiempoPreparacionMin != null)
                          Text('~${tienda.tiempoPreparacionMin} min', style: textos.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Abierto" en verde o "Cerrado" en gris.
class EtiquetaAbierto extends StatelessWidget {
  const EtiquetaAbierto({super.key, required this.abierto});

  final bool abierto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: abierto ? c.primary : c.outline),
        const SizedBox(width: 4),
        Text(
          abierto ? 'Abierto' : 'Cerrado',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: abierto ? c.primary : c.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Columnas de la grilla según el ancho (2 en celular, más en tablet o PC).
int columnasPara(double ancho) => (ancho / 190).floor().clamp(2, 6);
