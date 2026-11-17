import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/mapa.dart';
import '../../../core/maps/mapas.dart';
import '../../pedidos/domain/pedido.dart';
import '../data/envio_ubicacion.dart';

/// Mapa del repartidor con su pedido: él (su último GPS), la tienda y la casa
/// del cliente, con la línea de lo que le falta: a la tienda (si todavía no lo
/// recogió) y después a la casa. Es una línea recta entre los puntos (no
/// sigue las calles); para el camino exacto está "Cómo llegar".
class MapaReparto extends ConsumerWidget {
  const MapaReparto({super.key, required this.pedido, this.alto = 220});

  final Pedido pedido;
  final double alto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Mapas.disponibles) return const SizedBox.shrink();
    final yo = ref.watch(miUbicacionProvider);
    final tienda = pedido.negocioUbicacion;
    final casa = pedido.destino;
    final recogido = pedido.estado == EstadoPedido.enCamino;
    if (tienda == null && casa == null) return const SizedBox.shrink();

    return Card(
      key: const Key('mapa-reparto'),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: alto,
        child: MapaMdr(
          puntos: [
            if (tienda != null) PuntoMapa(TipoPunto.tienda, tienda, titulo: pedido.negocioNombre),
            if (casa != null) PuntoMapa(TipoPunto.casa, casa, titulo: pedido.clienteNombre ?? 'Cliente'),
            if (yo != null) PuntoMapa(TipoPunto.repartidor, yo, titulo: 'Tú'),
          ],
          ruta: [?yo, if (!recogido) ?tienda, ?casa],
        ),
      ),
    );
  }
}
