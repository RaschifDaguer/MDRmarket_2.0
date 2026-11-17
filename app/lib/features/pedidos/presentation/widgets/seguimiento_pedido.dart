import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/maps/mapa.dart';
import '../../../../core/maps/mapas.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido.dart';
import '../../domain/seguimiento.dart';

/// Cómo se dibuja el mapa del seguimiento (Google Maps con clave, si no
/// OpenStreetMap). Null = sin mapa (en las pruebas): se muestra solo el texto
/// con la distancia y el tiempo. Las pruebas lo reemplazan por un mapa falso.
final mapaSeguimientoProvider = Provider<Widget Function(Seguimiento)?>(
  (ref) => Mapas.disponibles ? (s) => MapaSeguimiento(seguimiento: s) : null,
);

/// Cada cuánto se vuelve a preguntar dónde está el repartidor.
const intervaloSeguimiento = Duration(seconds: 6);

/// "Llega en unos 8 min": mapa con el negocio, la casa y el repartidor (o el
/// texto, si no hay mapa) que se actualiza solo mientras el pedido va en camino.
/// [alCambiarEstado] avisa si el pedido cambió (ej. ya se entregó).
class SeguimientoPedido extends ConsumerStatefulWidget {
  const SeguimientoPedido({super.key, required this.pedidoId, required this.estado, this.alCambiarEstado});

  final int pedidoId;

  /// Estado que muestra la pantalla; si el seguimiento trae otro, se avisa.
  final EstadoPedido estado;
  final VoidCallback? alCambiarEstado;

  @override
  ConsumerState<SeguimientoPedido> createState() => _SeguimientoPedidoState();
}

class _SeguimientoPedidoState extends ConsumerState<SeguimientoPedido> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Primera versión: consultar cada pocos segundos (sin WebSockets).
    _reloj = Timer.periodic(intervaloSeguimiento, (_) => ref.invalidate(seguimientoProvider(widget.pedidoId)));
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(seguimientoProvider(widget.pedidoId), (_, nuevo) {
      final estado = nuevo.value?.estado;
      if (estado != null && estado != widget.estado) widget.alCambiarEstado?.call();
    });
    final seguimiento = ref.watch(seguimientoProvider(widget.pedidoId)).value;
    final mapa = ref.watch(mapaSeguimientoProvider);
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    if (seguimiento == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppEspacios.l),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final recogido = seguimiento.estado == EstadoPedido.enCamino;
    final llega = seguimiento.tiempoMin;
    return Card(
      key: const Key('seguimiento'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mapa != null) SizedBox(height: 240, child: mapa(seguimiento)),
          ListTile(
            leading: Icon(Icons.delivery_dining, color: c.primary, size: 32),
            title: Text(
              llega == null ? 'Esperando la ubicación del repartidor…' : 'Llega en unos $llega min',
              key: const Key('tiempo-estimado'),
              style: textos.titleMedium,
            ),
            subtitle: Text(
              [
                if (seguimiento.distanciaKm != null)
                  'A ${seguimiento.distanciaKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                recogido ? 'ya lo recogió' : 'pasa primero por ${seguimiento.negocioNombre}',
                if (seguimiento.haceSegundos != null) 'actualizado ${_hace(seguimiento.haceSegundos!)}',
              ].join(' · '),
              key: const Key('distancia-seguimiento'),
              style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          if (mapa == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppEspacios.m, 0, AppEspacios.m, AppEspacios.m - 4),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 16, color: c.onSurfaceVariant),
                  const SizedBox(width: AppEspacios.xs + 2),
                  Expanded(
                    child: Text(
                      'El mapa no está disponible en este dispositivo.',
                      style: textos.labelSmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _hace(int segundos) => segundos < 60 ? 'hace $segundos s' : 'hace ${segundos ~/ 60} min';
}

/// Mapa con la tienda, la casa del cliente y el repartidor (la moto). Cada
/// vez que llega una posición nueva (cada pocos segundos, de
/// `GET /api/pedidos/{id}/seguimiento`), la moto se mueve y el mapa encuadra a
/// los tres. La línea va de la moto a la tienda (si todavía no lo recogió) y a la casa.
class MapaSeguimiento extends StatelessWidget {
  const MapaSeguimiento({super.key, required this.seguimiento});

  final Seguimiento seguimiento;

  @override
  Widget build(BuildContext context) {
    final s = seguimiento;
    final recogido = s.estado == EstadoPedido.enCamino;
    return MapaMdr(
      key: const Key('mapa-seguimiento'),
      puntos: [
        PuntoMapa(TipoPunto.tienda, s.negocio, titulo: s.negocioNombre),
        PuntoMapa(TipoPunto.casa, s.destino, titulo: 'Tu casa'),
        if (s.repartidor != null)
          PuntoMapa(TipoPunto.repartidor, s.repartidor!, titulo: s.repartidorNombre ?? 'Repartidor'),
      ],
      ruta: [?s.repartidor, if (!recogido) s.negocio, s.destino],
    );
  }
}
