import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/maps/coordenada.dart';
import '../../../../core/maps/mapas.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido.dart';
import '../../domain/seguimiento.dart';

/// Cómo se dibuja el mapa del seguimiento. Null = sin mapa (no hay clave de
/// Google Maps): se muestra solo el texto con la distancia y el tiempo. Las
/// pruebas lo reemplazan por un mapa falso.
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
      return const Card(child: Padding(padding: EdgeInsets.all(AppEspacios.l), child: Center(child: CircularProgressIndicator())));
    }

    final recogido = seguimiento.estado == EstadoPedido.enCamino;
    final llega = seguimiento.tiempoMin;
    return Card(
      key: const Key('seguimiento'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mapa != null && seguimiento.repartidor != null)
            SizedBox(height: 240, child: mapa(seguimiento)),
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
                    child: Text('El mapa no está disponible en este dispositivo.',
                        style: textos.labelSmall?.copyWith(color: c.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _hace(int segundos) =>
      segundos < 60 ? 'hace $segundos s' : 'hace ${segundos ~/ 60} min';
}

/// Mapa de Google con el negocio, la casa del cliente y el repartidor. Al
/// llegar una posición nueva, el marcador se mueve y el mapa los encuadra a los tres.
class MapaSeguimiento extends StatefulWidget {
  const MapaSeguimiento({super.key, required this.seguimiento});

  final Seguimiento seguimiento;

  @override
  State<MapaSeguimiento> createState() => _MapaSeguimientoState();
}

class _MapaSeguimientoState extends State<MapaSeguimiento> {
  GoogleMapController? _mapa;

  static LatLng _latLng(Coordenada c) => LatLng(c.latitud, c.longitud);

  List<Coordenada> get _puntos => [
        widget.seguimiento.negocio,
        widget.seguimiento.destino,
        ?widget.seguimiento.repartidor,
      ];

  LatLngBounds get _limites {
    final lat = _puntos.map((p) => p.latitud);
    final lng = _puntos.map((p) => p.longitud);
    return LatLngBounds(
      southwest: LatLng(lat.reduce(math.min), lng.reduce(math.min)),
      northeast: LatLng(lat.reduce(math.max), lng.reduce(math.max)),
    );
  }

  @override
  void didUpdateWidget(covariant MapaSeguimiento anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.seguimiento.repartidor != widget.seguimiento.repartidor) {
      _mapa?.animateCamera(CameraUpdate.newLatLngBounds(_limites, 48));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.seguimiento;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _latLng(s.repartidor ?? s.destino), zoom: 14),
      onMapCreated: (control) {
        _mapa = control;
        control.moveCamera(CameraUpdate.newLatLngBounds(_limites, 48));
      },
      markers: {
        Marker(
          markerId: const MarkerId('negocio'),
          position: _latLng(s.negocio),
          infoWindow: InfoWindow(title: s.negocioNombre),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
        Marker(
          markerId: const MarkerId('casa'),
          position: _latLng(s.destino),
          infoWindow: const InfoWindow(title: 'Tu casa'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        if (s.repartidor != null)
          Marker(
            markerId: const MarkerId('repartidor'),
            position: _latLng(s.repartidor!),
            infoWindow: InfoWindow(title: s.repartidorNombre ?? 'Repartidor'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
      },
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      // Dentro de una lista con scroll, el mapa se queda con el gesto.
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
    );
  }
}
