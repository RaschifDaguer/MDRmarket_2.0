import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/mapa.dart';
import '../../../core/maps/mapas.dart';
import '../../pedidos/domain/pedido.dart';
import '../data/envio_ubicacion.dart';
import '../data/ruta_reparto.dart';

/// Mapa del repartidor con su pedido: él (la moto, con su GPS en vivo), la
/// tienda y el cliente, con la ruta por las calles de lo que le falta: a la
/// tienda (si todavía no lo recogió) y después a la casa. Lo ya recorrido
/// desaparece de la línea. Para ir guiado, el modo GPS ("Cómo llegar").
class MapaReparto extends ConsumerWidget {
  const MapaReparto({super.key, required this.pedido, this.alto = 220});

  final Pedido pedido;
  final double alto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Mapas.disponibles) return const SizedBox.shrink();
    final yo = ref.watch(miUbicacionProvider);
    final ruta = ref.watch(rutaRepartoProvider);
    final tienda = pedido.negocioUbicacion;
    final casa = pedido.destino;
    if (tienda == null && casa == null) return const SizedBox.shrink();

    return Card(
      key: const Key('mapa-reparto'),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: alto,
        child: ListenableBuilder(
          listenable: ruta,
          builder: (context, _) => MapaMdr(
            puntos: [
              if (tienda != null) PuntoMapa(TipoPunto.tienda, tienda, titulo: pedido.negocioNombre),
              if (casa != null) PuntoMapa(TipoPunto.casa, casa, titulo: pedido.clienteNombre ?? 'Cliente'),
              if (yo != null) PuntoMapa(TipoPunto.repartidor, yo, titulo: 'Tú'),
            ],
            ruta: ruta.lineaRestante,
            rutaPorCalles: ruta.ruta?.porCalles ?? false,
          ),
        ),
      ),
    );
  }
}
