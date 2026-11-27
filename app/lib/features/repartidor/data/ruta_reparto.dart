import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/coordenada.dart';
import '../../../core/maps/mapas_repository.dart';
import '../../../core/maps/ruta_viva.dart';
import '../../pedidos/domain/pedido.dart';
import 'envio_ubicacion.dart';
import 'repartidor_repository.dart';

/// Las paradas que le quedan: la tienda (si todavía no lo recogió) y la casa del cliente.
List<Coordenada> paradasDelReparto(Pedido p) => [
  if (p.estado != EstadoPedido.enCamino && p.negocioUbicacion != null) p.negocioUbicacion!,
  ?p.destino,
];

/// La ruta por las calles del pedido que lleva, desde donde está. La comparten
/// el mapa del pedido y el modo GPS (se calcula una vez). Se actualiza sola con
/// cada lectura del GPS y cuando cambia el pedido (ej. ya lo recogió).
final rutaRepartoProvider = Provider.autoDispose<RutaViva>((ref) {
  final ruta = RutaViva(
    pedir: (puntos) => ref
        .read(mapasRepositoryProvider)
        .ruta(puntos, vehiculo: vehiculoParaRuta(ref.read(miRepartidorProvider).value?.vehiculo?.tipoCodigo)),
  );
  ref.onDispose(ruta.dispose);

  void actualizar() {
    final pedido = ref.read(pedidoActualProvider).value;
    if (pedido == null) return;
    ruta.actualizar(origen: ref.read(miUbicacionProvider), paradas: paradasDelReparto(pedido));
  }

  ref.listen(miUbicacionProvider, (_, _) => actualizar());
  ref.listen(
    pedidoActualProvider.select((a) => (a.value?.id, a.value?.estado)),
    (_, _) => actualizar(),
    fireImmediately: true,
  );
  return ruta;
});
