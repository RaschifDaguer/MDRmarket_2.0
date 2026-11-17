import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/formato.dart';
import '../../../core/theme/app_colores.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/usuario.dart';
import '../../notificaciones/data/notificaciones_repository.dart';
import '../../pedidos/data/pedidos_repository.dart';
import '../data/catalogo_repository.dart';
import '../domain/producto.dart';
import '../domain/tienda.dart';
import 'catalogo_view.dart';
import 'widgets/tarjetas_catalogo.dart';

/// Pestaña "Inicio" del cliente: dónde recibe, saludo, categorías, tiendas
/// cerca (con envío y tiempo según su dirección), ofertas del día y, abajo,
/// todos los productos con sus filtros.
class InicioView extends ConsumerWidget {
  const InicioView({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: CatalogoView(
        conBuscador: false,
        titulo: 'Todos los productos',
        encabezado: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Aparecer(child: _Cabecera(usuario: usuario)),
            const SizedBox(height: AppEspacios.m),
            const Aparecer(orden: 1, child: _Portada()),
            const SizedBox(height: AppEspacios.l),
            const Aparecer(orden: 2, child: _Categorias()),
            const SizedBox(height: AppEspacios.l),
            const Aparecer(orden: 3, child: _TiendasCerca()),
            const _OfertasDelDia(),
          ],
        ),
      ),
    );
  }
}

/// "Entregar en Casa · Av. Banzer" + "Hola Sofía, ¿qué necesitas hoy?" y la campana.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final entrega = ref.watch(entregaClienteProvider).value;
    final noLeidas = ref.watch(notificacionesProvider).value?.noLeidas ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: const Key('entregar-en'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/direcciones'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_outlined, size: 18, color: c.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Entregar en  ',
                                style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                              ),
                              TextSpan(
                                text: entrega == null
                                    ? 'Agrega tu dirección'
                                    : [
                                        entrega.titulo,
                                        if (entrega.titulo != entrega.direccion) entrega.direccion,
                                      ].join(' · '),
                                style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: c.primary),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.expand_more, size: 18, color: c.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppEspacios.xs),
              Text(
                'Hola ${usuario.nombre}, ¿qué necesitas hoy?',
                style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('abrir-notificaciones'),
          tooltip: noLeidas > 0 ? 'Notificaciones ($noLeidas sin leer)' : 'Notificaciones',
          onPressed: () => context.push('/notificaciones'),
          icon: Badge(
            isLabelVisible: noLeidas > 0,
            label: Text('$noLeidas'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}

/// Portada decorativa (sin promociones: no hay descuentos reales en la API).
class _Portada extends StatelessWidget {
  const _Portada();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppEspacios.m + 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColores.primario, AppColores.primarioOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todo Santa Cruz, a tu puerta',
                  style: textos.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tiendas de tu ciudad con repartidores de MDR Market.',
                  style: textos.bodySmall?.copyWith(color: AppColores.muyClaro),
                ),
                const SizedBox(height: AppEspacios.s + 2),
                InkWell(
                  key: const Key('portada-ver-tiendas'),
                  onTap: () => context.push('/tiendas'),
                  child: Text(
                    'Ver tiendas →',
                    style: textos.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppEspacios.s),
          const Icon(Icons.delivery_dining_rounded, size: 56, color: AppColores.claro),
        ],
      ),
    );
  }
}

/// Rubros de la API, en grilla. Tocar uno abre la búsqueda filtrada.
class _Categorias extends ConsumerWidget {
  const _Categorias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasProvider).value ?? const [];
    if (categorias.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TituloFila(titulo: 'Categorías', accion: 'Ver tiendas', alTocar: () => context.push('/tiendas')),
        const SizedBox(height: AppEspacios.s),
        SizedBox(
          // Ícono (58) + dos líneas de texto, que crecen con la letra del sistema.
          height: 66 + MediaQuery.textScalerOf(context).scale(34),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categorias.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppEspacios.s + 4),
            itemBuilder: (context, i) {
              final categoria = categorias[i];
              return InkWell(
                key: Key('categoria-${categoria.id}'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/buscar?categoria=${categoria.id}'),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                        child: Text(categoria.icono ?? '🛍️', style: const TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        categoria.nombre,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: textos.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: c.onSurface),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "Tiendas cerca de ti": con la dirección del cliente, de la más cercana a la
/// más lejana, con su tiempo y envío.
class _TiendasCerca extends ConsumerWidget {
  const _TiendasCerca();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiendas = ref.watch(tiendasCercaProvider).value ?? const <Tienda>[];
    if (tiendas.isEmpty) return const SizedBox.shrink();
    final conDireccion = tiendas.any((t) => t.envio != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TituloFila(
          titulo: conDireccion ? 'Tiendas cerca de ti' : 'Tiendas',
          accion: 'Ver todas',
          alTocar: () => context.push('/tiendas'),
        ),
        const SizedBox(height: AppEspacios.s),
        SizedBox(
          height: 52 + MediaQuery.textScalerOf(context).scale(36),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tiendas.length.clamp(0, 8),
            separatorBuilder: (_, _) => const SizedBox(width: AppEspacios.s + 2),
            itemBuilder: (context, i) => _TiendaChica(tienda: tiendas[i]),
          ),
        ),
        const SizedBox(height: AppEspacios.l),
      ],
    );
  }
}

class _TiendaChica extends StatelessWidget {
  const _TiendaChica({required this.tienda});

  final Tienda tienda;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final envio = tienda.envio;
    final detalle = switch (envio) {
      EnvioTienda(enCobertura: true) => '${envio.tiempoTexto} · Envío ${Formato.bs(envio.costoEnvio)}',
      EnvioTienda() => 'Fuera de tu zona',
      null => tienda.abierto ? 'Abierto' : 'Cerrado',
    };

    return SizedBox(
      width: 230,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          key: Key('tienda-cerca-${tienda.id}'),
          onTap: () => context.push('/tienda/${tienda.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppEspacios.s + 2),
            child: Row(
              children: [
                ImagenRed(tienda.logoUrl, ancho: 48, alto: 48, icono: Icons.storefront),
                const SizedBox(width: AppEspacios.s + 2),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tienda.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: textos.titleSmall),
                      Text(
                        detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ofertas del día": productos con oferta vigente.
class _OfertasDelDia extends ConsumerWidget {
  const _OfertasDelDia();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ofertas = ref.watch(ofertasProvider).value ?? const <Producto>[];
    if (ofertas.isEmpty) return const SizedBox.shrink();

    return Aparecer(
      orden: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TituloFila(titulo: 'Ofertas del día'),
          const SizedBox(height: AppEspacios.s),
          SizedBox(
            // Igual que la tarjeta de la grilla: foto 4:3 + el texto (que crece con la letra).
            height: 150 * 3 / 4 + MediaQuery.textScalerOf(context).scale(122),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ofertas.length.clamp(0, 10),
              separatorBuilder: (_, _) => const SizedBox(width: AppEspacios.s + 2),
              itemBuilder: (context, i) => SizedBox(
                width: 150,
                child: TarjetaProducto(
                  prefijoClave: 'oferta',
                  producto: ofertas[i],
                  alTocar: () => context.push('/producto/${ofertas[i].id}'),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppEspacios.l),
        ],
      ),
    );
  }
}

/// Título de una sección con un enlace a la derecha ("Ver todas").
class _TituloFila extends StatelessWidget {
  const _TituloFila({required this.titulo, this.accion, this.alTocar});

  final String titulo;
  final String? accion;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(titulo, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (accion != null) TextButton(onPressed: alTocar, child: Text(accion!)),
      ],
    );
  }
}
