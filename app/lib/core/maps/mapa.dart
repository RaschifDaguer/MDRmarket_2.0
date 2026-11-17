import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_movimiento.dart';
import 'coordenada.dart';
import 'mapas.dart';

/// Qué es cada marcador del mapa (define el ícono y el color).
enum TipoPunto { tienda, casa, repartidor, elegido }

/// Un marcador: dónde y qué es.
class PuntoMapa {
  const PuntoMapa(this.tipo, this.punto, {this.titulo});

  final TipoPunto tipo;
  final Coordenada punto;
  final String? titulo;

  @override
  bool operator ==(Object other) => other is PuntoMapa && other.tipo == tipo && other.punto == punto;

  @override
  int get hashCode => Object.hash(tipo, punto);
}

/// Mapa de la app. Con clave de Google Maps usa Google Maps; sin clave, usa
/// OpenStreetMap con flutter_map (gratis, sin clave), con la atribución
/// visible y el user-agent de la app como pide su política de uso.
///
/// Muestra [puntos] (tienda, casa, repartidor…), una [ruta] (línea entre
/// puntos) y, si se pasa [alTocar], deja elegir un punto tocando el mapa.
/// Cuando cambian los puntos (ej. se movió el repartidor) vuelve a encuadrarlos;
/// con "reducir movimiento" la cámara salta en vez de deslizarse.
class MapaMdr extends StatefulWidget {
  const MapaMdr({
    super.key,
    this.puntos = const [],
    this.ruta = const [],
    this.alTocar,
    this.centro = Coordenada.centroSantaCruz,
    this.zoom = 15,
  });

  final List<PuntoMapa> puntos;
  final List<Coordenada> ruta;
  final ValueChanged<Coordenada>? alTocar;

  /// Dónde se centra si no hay puntos (o hay uno solo).
  final Coordenada centro;
  final double zoom;

  /// Datos de OpenStreetMap (atribución y política de uso).
  static const urlTeselas = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'bo.mdrmarket.app';
  static const textoAtribucion = '© OpenStreetMap';
  static final urlCopyright = Uri.parse('https://www.openstreetmap.org/copyright');

  @override
  State<MapaMdr> createState() => _MapaMdrState();
}

class _MapaMdrState extends State<MapaMdr> {
  final _osm = osm.MapController();
  g.GoogleMapController? _google;
  bool _osmListo = false;

  List<Coordenada> get _todos => [for (final p in widget.puntos) p.punto, ...widget.ruta];

  @override
  void didUpdateWidget(covariant MapaMdr anterior) {
    super.didUpdateWidget(anterior);
    if (!listEquals(anterior.puntos, widget.puntos)) _encuadrar(animar: true);
  }

  @override
  void dispose() {
    _osm.dispose();
    super.dispose();
  }

  void _encuadrar({bool animar = false}) {
    final todos = _todos;
    if (Mapas.google) {
      final control = _google;
      if (control == null) return;
      final cambio = todos.length < 2
          ? g.CameraUpdate.newLatLngZoom(_g(todos.firstOrNull ?? widget.centro), widget.zoom)
          : g.CameraUpdate.newLatLngBounds(_limitesGoogle(todos), 48);
      animar && AppMovimiento.activo(context) ? control.animateCamera(cambio) : control.moveCamera(cambio);
      return;
    }
    if (!_osmListo) return;
    if (todos.length < 2) {
      _osm.move(_ll(todos.firstOrNull ?? widget.centro), _osm.camera.zoom);
    } else {
      _osm.fitCamera(
        osm.CameraFit.bounds(
          bounds: osm.LatLngBounds.fromPoints([for (final p in todos) _ll(p)]),
          padding: const EdgeInsets.all(48),
          maxZoom: 17,
        ),
      );
    }
  }

  static ll.LatLng _ll(Coordenada c) => ll.LatLng(c.latitud, c.longitud);
  static g.LatLng _g(Coordenada c) => g.LatLng(c.latitud, c.longitud);

  static g.LatLngBounds _limitesGoogle(List<Coordenada> puntos) {
    final lat = puntos.map((p) => p.latitud);
    final lng = puntos.map((p) => p.longitud);
    return g.LatLngBounds(
      southwest: g.LatLng(lat.reduce(math.min), lng.reduce(math.min)),
      northeast: g.LatLng(lat.reduce(math.max), lng.reduce(math.max)),
    );
  }

  static (IconData, Color) _estilo(TipoPunto tipo, ColorScheme c) => switch (tipo) {
    TipoPunto.tienda => (Icons.storefront, Colors.orange.shade800),
    TipoPunto.casa => (Icons.home, Colors.red.shade700),
    TipoPunto.repartidor => (Icons.two_wheeler, c.primary),
    TipoPunto.elegido => (Icons.place, c.primary),
  };

  static double _tonoGoogle(TipoPunto tipo) => switch (tipo) {
    TipoPunto.tienda => g.BitmapDescriptor.hueOrange,
    TipoPunto.casa => g.BitmapDescriptor.hueRed,
    TipoPunto.repartidor => g.BitmapDescriptor.hueGreen,
    TipoPunto.elegido => g.BitmapDescriptor.hueAzure,
  };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final inicio = widget.puntos.length == 1 ? widget.puntos.first.punto : widget.centro;
    // Dentro de una lista con scroll, el mapa se queda con el gesto.
    final gestos = {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)};

    if (Mapas.google) {
      return g.GoogleMap(
        initialCameraPosition: g.CameraPosition(target: _g(inicio), zoom: widget.zoom),
        onMapCreated: (control) {
          _google = control;
          _encuadrar();
        },
        onTap: widget.alTocar == null ? null : (p) => widget.alTocar!(Coordenada(p.latitude, p.longitude)),
        markers: {
          for (final p in widget.puntos)
            g.Marker(
              markerId: g.MarkerId(p.tipo.name),
              position: _g(p.punto),
              infoWindow: p.titulo == null ? g.InfoWindow.noText : g.InfoWindow(title: p.titulo),
              icon: g.BitmapDescriptor.defaultMarkerWithHue(_tonoGoogle(p.tipo)),
              draggable: p.tipo == TipoPunto.elegido && widget.alTocar != null,
              onDragEnd: widget.alTocar == null ? null : (q) => widget.alTocar!(Coordenada(q.latitude, q.longitude)),
            ),
        },
        polylines: {
          if (widget.ruta.length > 1)
            g.Polyline(
              polylineId: const g.PolylineId('ruta'),
              points: [for (final p in widget.ruta) _g(p)],
              color: c.primary,
              width: 4,
            ),
        },
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        gestureRecognizers: gestos,
      );
    }

    return Semantics(
      label: 'Mapa: ${widget.puntos.map((p) => p.titulo ?? p.tipo.name).join(', ')}',
      child: osm.FlutterMap(
        mapController: _osm,
        options: osm.MapOptions(
          initialCenter: _ll(inicio),
          initialZoom: widget.zoom,
          initialCameraFit: _todos.length < 2
              ? null
              : osm.CameraFit.bounds(
                  bounds: osm.LatLngBounds.fromPoints([for (final p in _todos) _ll(p)]),
                  padding: const EdgeInsets.all(48),
                  maxZoom: 17,
                ),
          onMapReady: () => _osmListo = true,
          onTap: widget.alTocar == null ? null : (_, p) => widget.alTocar!(Coordenada(p.latitude, p.longitude)),
          interactionOptions: const osm.InteractionOptions(
            flags: osm.InteractiveFlag.all & ~osm.InteractiveFlag.rotate,
          ),
        ),
        children: [
          osm.TileLayer(
            urlTemplate: MapaMdr.urlTeselas,
            // Política de uso de OpenStreetMap: identificar la app (en web lo pone el navegador).
            userAgentPackageName: MapaMdr.userAgent,
            tileProvider: Mapas.teselasDePrueba,
            maxNativeZoom: 19,
          ),
          if (widget.ruta.length > 1)
            osm.PolylineLayer(
              polylines: [
                osm.Polyline(points: [for (final p in widget.ruta) _ll(p)], color: c.primary, strokeWidth: 4),
              ],
            ),
          osm.MarkerLayer(
            markers: [
              for (final p in widget.puntos)
                osm.Marker(
                  key: Key('marcador-${p.tipo.name}'),
                  point: _ll(p.punto),
                  width: 40,
                  height: 40,
                  alignment: p.tipo == TipoPunto.elegido ? Alignment.topCenter : Alignment.center,
                  child: _Marcador(tipo: p.tipo, estilo: _estilo(p.tipo, c), titulo: p.titulo),
                ),
            ],
          ),
          // Atribución siempre visible (requisito de OpenStreetMap).
          osm.SimpleAttributionWidget(
            key: const Key('atribucion-osm'),
            source: const Text(MapaMdr.textoAtribucion),
            backgroundColor: c.surface.withValues(alpha: 0.85),
            onTap: () => launchUrl(MapaMdr.urlCopyright, mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.tipo, required this.estilo, this.titulo});

  final TipoPunto tipo;
  final (IconData, Color) estilo;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final (icono, color) = estilo;
    if (tipo == TipoPunto.elegido) return Icon(icono, color: color, size: 40);
    return Tooltip(
      message: titulo ?? '',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
        child: Center(child: Icon(icono, color: Colors.white, size: 20)),
      ),
    );
  }
}
