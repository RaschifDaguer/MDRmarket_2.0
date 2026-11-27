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
import 'iconos_mapa.dart';
import 'mapas.dart';

/// Qué es cada marcador del mapa (define el ícono y el color): la tienda, el
/// cliente (su casa), el repartidor (la moto) y el punto que se está eligiendo.
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

/// Mapa de la app. Con clave de Google Maps usa Google Maps; sin clave (ej. la
/// web), OpenStreetMap con flutter_map (gratis, sin clave), con la atribución
/// visible y el user-agent de la app como pide su política de uso.
///
/// - [puntos]: la tienda (ícono de tienda), el cliente (una persona) y el
///   repartidor (una moto). Cuando un punto se mueve, el marcador se desliza
///   hasta el lugar nuevo (sin saltos); con "reducir movimiento" salta.
/// - [ruta]: la línea del recorrido (por las calles; punteada si es recta).
/// - [seguir]: la cámara acompaña a ese punto (modo GPS del repartidor).
/// - [alTocar]: deja elegir un punto tocando el mapa.
///
/// La cámara encuadra los puntos al abrir y solo vuelve a encuadrar si aparece
/// uno nuevo o alguno queda fuera de la vista: así no "salta" con cada posición.
class MapaMdr extends StatefulWidget {
  const MapaMdr({
    super.key,
    this.puntos = const [],
    this.ruta = const [],
    this.rutaPorCalles = true,
    this.alTocar,
    this.seguir,
    this.centro = Coordenada.centroSantaCruz,
    this.zoom = 15,
    this.zoomSeguir = 17,
    this.relleno = const EdgeInsets.all(48),
    this.deslizarDurante = duracionMovimiento,
  });

  /// Cuánto tarda un marcador en llegar a su posición nueva. En el seguimiento
  /// del cliente, casi lo que tarda en llegar la siguiente: la moto avanza
  /// sin pausas en vez de ir a saltos.
  final Duration deslizarDurante;

  final List<PuntoMapa> puntos;
  final List<Coordenada> ruta;
  final bool rutaPorCalles;
  final ValueChanged<Coordenada>? alTocar;
  final Coordenada? seguir;

  /// Dónde se centra si no hay puntos (o hay uno solo).
  final Coordenada centro;
  final double zoom;
  final double zoomSeguir;

  /// Margen al encuadrar (ej. más abajo si hay un panel encima del mapa).
  final EdgeInsets relleno;

  /// Datos de OpenStreetMap (atribución y política de uso).
  static const urlTeselas = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'bo.mdrmarket.app';
  static const textoAtribucion = '© OpenStreetMap';
  static final urlCopyright = Uri.parse('https://www.openstreetmap.org/copyright');

  /// Cuánto tarda un marcador en deslizarse hasta su posición nueva.
  static const duracionMovimiento = Duration(milliseconds: 1200);

  /// Ícono y color de cada marcador.
  static (IconData, Color) estilo(TipoPunto tipo, ColorScheme c) => switch (tipo) {
    TipoPunto.tienda => (Icons.storefront, Colors.orange.shade800),
    TipoPunto.casa => (Icons.person, Colors.red.shade700),
    TipoPunto.repartidor => (Icons.two_wheeler, c.primary),
    TipoPunto.elegido => (Icons.place, c.primary),
  };

  @override
  State<MapaMdr> createState() => _MapaMdrState();
}

class _MapaMdrState extends State<MapaMdr> with SingleTickerProviderStateMixin {
  final _osm = osm.MapController();
  g.GoogleMapController? _google;
  bool _osmListo = false;

  /// Deslizar los marcadores: de dónde a dónde va cada uno.
  late final _movimiento = AnimationController(vsync: this, duration: widget.deslizarDurante)
    ..addListener(_alMover);

  /// Deslizamientos largos (seguimiento): a velocidad pareja, como una moto.
  Curve get _curva => widget.deslizarDurante >= const Duration(seconds: 2) ? Curves.linear : Curves.easeInOut;
  final _desde = <TipoPunto, Coordenada>{};
  final _hasta = <TipoPunto, Coordenada>{};
  final _iconos = <TipoPunto, g.BitmapDescriptor>{};
  String? _clavesIconos;

  List<Coordenada> get _todos => [for (final p in widget.puntos) p.punto, ...widget.ruta];

  @override
  void initState() {
    super.initState();
    for (final p in widget.puntos) {
      _desde[p.tipo] = p.punto;
      _hasta[p.tipo] = p.punto;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Mapas.google) _cargarIconos();
  }

  @override
  void didUpdateWidget(covariant MapaMdr anterior) {
    super.didUpdateWidget(anterior);
    _movimiento.duration = widget.deslizarDurante;
    if (listEquals(anterior.puntos, widget.puntos) && anterior.seguir == widget.seguir) return;

    // Cada marcador sale de donde se ve ahora (aunque estuviera a mitad de camino).
    final ahora = _mostrados();
    final deslizar = AppMovimiento.activo(context);
    _desde.clear();
    _hasta.clear();
    for (final p in widget.puntos) {
      final antes = ahora[p.tipo];
      // Lejos (ej. otro pedido) o sin "antes": salta directo.
      final cerca = antes != null && antes.distanciaKm(p.punto) < 0.5;
      _desde[p.tipo] = deslizar && cerca ? antes : p.punto;
      _hasta[p.tipo] = p.punto;
    }
    if (deslizar && _desde.entries.any((e) => e.value != _hasta[e.key])) {
      _movimiento.forward(from: 0);
    } else {
      _movimiento.value = 1;
    }

    final otrosTipos = !setEquals(
      {for (final p in anterior.puntos) p.tipo},
      {for (final p in widget.puntos) p.tipo},
    );
    if (widget.seguir != null) {
      _seguirA(widget.seguir!);
    } else if (otrosTipos) {
      _encuadrar(animar: true);
    } else {
      _encuadrarSiQuedaFuera();
    }
  }

  @override
  void dispose() {
    _movimiento.dispose();
    _osm.dispose();
    super.dispose();
  }

  /// Dónde se dibuja cada marcador en este momento del deslizamiento.
  Map<TipoPunto, Coordenada> _mostrados() {
    final t = _curva.transform(_movimiento.isAnimating ? _movimiento.value : 1);
    return {
      for (final tipo in _hasta.keys)
        tipo: Coordenada(
          _lerp(_desde[tipo]!.latitud, _hasta[tipo]!.latitud, t),
          _lerp(_desde[tipo]!.longitud, _hasta[tipo]!.longitud, t),
        ),
    };
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _alMover() {
    if (!mounted) return;
    setState(() {});
    // En OpenStreetMap la cámara acompaña cuadro a cuadro.
    final seguir = widget.seguir;
    if (seguir != null && !Mapas.google && _osmListo) {
      final repartidor = _mostrados()[TipoPunto.repartidor] ?? seguir;
      _osm.move(_ll(repartidor), _osm.camera.zoom);
    }
  }

  Future<void> _cargarIconos() async {
    final c = Theme.of(context).colorScheme;
    final densidad = MediaQuery.devicePixelRatioOf(context);
    final clave = '${c.primary.toARGB32()}-$densidad';
    if (clave == _clavesIconos) return;
    _clavesIconos = clave;
    for (final tipo in [TipoPunto.tienda, TipoPunto.casa, TipoPunto.repartidor]) {
      final (icono, color) = MapaMdr.estilo(tipo, c);
      final hecho = await IconosMapa.de(icono, color, densidad);
      if (!mounted) return;
      setState(() => _iconos[tipo] = hecho);
    }
  }

  void _seguirA(Coordenada punto) {
    if (Mapas.google) {
      _google?.animateCamera(g.CameraUpdate.newLatLng(_g(punto)));
    } else if (_osmListo && !_movimiento.isAnimating) {
      _osm.move(_ll(punto), _osm.camera.zoom);
    }
  }

  /// Vuelve a encuadrar todo (o al punto que sigue): el botón "Centrar".
  void _centrar() {
    final seguir = widget.seguir;
    if (seguir == null) {
      _encuadrar(animar: true);
    } else if (Mapas.google) {
      _google?.animateCamera(g.CameraUpdate.newLatLngZoom(_g(seguir), widget.zoomSeguir));
    } else if (_osmListo) {
      _osm.move(_ll(seguir), widget.zoomSeguir);
    }
  }

  Future<void> _encuadrarSiQuedaFuera() async {
    final puntos = [for (final p in widget.puntos) p.punto];
    if (puntos.isEmpty) return;
    if (Mapas.google) {
      final control = _google;
      if (control == null) return;
      try {
        final vista = await control.getVisibleRegion();
        if (puntos.any((p) => !vista.contains(_g(p)))) _encuadrar(animar: true);
      } catch (_) {}
      return;
    }
    if (!_osmListo) return;
    final vista = _osm.camera.visibleBounds;
    if (puntos.any((p) => !vista.contains(_ll(p)))) _encuadrar(animar: true);
  }

  void _encuadrar({bool animar = false}) {
    final todos = _todos;
    final seguir = widget.seguir;
    if (Mapas.google) {
      final control = _google;
      if (control != null) _encuadrarGoogle(control, todos, animar: animar);
      return;
    }
    if (!_osmListo) return;
    if (seguir != null) {
      _osm.move(_ll(seguir), widget.zoomSeguir);
    } else if (todos.length < 2) {
      _osm.move(_ll(todos.firstOrNull ?? widget.centro), widget.puntos.length == 1 ? widget.zoom : _osm.camera.zoom);
    } else {
      _osm.fitCamera(
        osm.CameraFit.bounds(
          bounds: osm.LatLngBounds.fromPoints([for (final p in todos) _ll(p)]),
          padding: widget.relleno,
          maxZoom: 17,
        ),
      );
    }
  }

  /// Google Maps en Android: recién creado, el mapa puede no tener tamaño
  /// todavía y encuadrar falla ("Map size can't be 0"); entonces quedaba en el
  /// centro de la ciudad. Se reintenta unas veces, con una pausa corta.
  Future<void> _encuadrarGoogle(g.GoogleMapController control, List<Coordenada> todos, {required bool animar}) async {
    final seguir = widget.seguir;
    final relleno = math.max(widget.relleno.top, widget.relleno.bottom);
    final cambio = seguir != null
        ? g.CameraUpdate.newLatLngZoom(_g(seguir), widget.zoomSeguir)
        : todos.length < 2
        ? g.CameraUpdate.newLatLngZoom(_g(todos.firstOrNull ?? widget.centro), widget.zoom)
        : g.CameraUpdate.newLatLngBounds(_limitesGoogle(todos), relleno);
    final deslizar = animar && AppMovimiento.activo(context);
    for (var intento = 0; intento < 4; intento++) {
      if (!mounted) return;
      try {
        if (deslizar) {
          await control.animateCamera(cambio);
        } else {
          await control.moveCamera(cambio);
        }
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
  }

  /// Punto medio de todos los puntos: así el mapa ya arranca cerca de ellos.
  static Coordenada _centroDe(List<Coordenada> puntos) => Coordenada(
    puntos.map((p) => p.latitud).reduce((a, b) => a + b) / puntos.length,
    puntos.map((p) => p.longitud).reduce((a, b) => a + b) / puntos.length,
  );

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

  static double _tonoGoogle(TipoPunto tipo) => switch (tipo) {
    TipoPunto.tienda => g.BitmapDescriptor.hueOrange,
    TipoPunto.casa => g.BitmapDescriptor.hueRed,
    TipoPunto.repartidor => g.BitmapDescriptor.hueGreen,
    TipoPunto.elegido => g.BitmapDescriptor.hueAzure,
  };

  /// El botón para volver a encuadrar (si movió el mapa con el dedo).
  Widget _botonCentrar(ColorScheme c) => Positioned(
    right: 10,
    bottom: Mapas.google ? 10 : 28,
    child: Material(
      color: c.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        key: const Key('mapa-centrar'),
        tooltip: widget.seguir != null ? 'Volver a mi ubicación' : 'Ver todo el recorrido',
        icon: Icon(widget.seguir != null ? Icons.my_location : Icons.center_focus_strong, color: c.primary),
        onPressed: _centrar,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final inicio = widget.seguir ?? (widget.puntos.length == 1 ? widget.puntos.first.punto : widget.centro);
    // Dentro de una lista con scroll, el mapa se queda con el gesto.
    final gestos = {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)};
    final mostrados = _mostrados();
    final conCentrar = widget.alTocar == null && (widget.puntos.length > 1 || widget.seguir != null);

    if (Mapas.google) {
      final todos = _todos;
      final mapa = g.GoogleMap(
        // Con varios puntos (tienda, casa, repartidor) arranca entre ellos y después los encuadra.
        initialCameraPosition: g.CameraPosition(
          target: _g(widget.seguir != null || todos.length < 2 ? inicio : _centroDe(todos)),
          zoom: widget.seguir != null ? widget.zoomSeguir : (todos.length < 2 ? widget.zoom : 13),
        ),
        onMapCreated: (control) {
          _google = control;
          // Recién después del primer dibujo el mapa tiene tamaño para encuadrar.
          WidgetsBinding.instance.addPostFrameCallback((_) => _encuadrar());
        },
        onTap: widget.alTocar == null ? null : (p) => widget.alTocar!(Coordenada(p.latitude, p.longitude)),
        markers: {
          for (final p in widget.puntos)
            g.Marker(
              markerId: g.MarkerId(p.tipo.name),
              position: _g(mostrados[p.tipo] ?? p.punto),
              infoWindow: p.titulo == null ? g.InfoWindow.noText : g.InfoWindow(title: p.titulo),
              icon: _iconos[p.tipo] ?? g.BitmapDescriptor.defaultMarkerWithHue(_tonoGoogle(p.tipo)),
              // Los íconos redondos van centrados en el punto; el alfiler, con la punta abajo.
              anchor: _iconos[p.tipo] != null ? const Offset(0.5, 0.5) : const Offset(0.5, 1),
              zIndexInt: p.tipo == TipoPunto.repartidor ? 2 : 1,
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
              width: 5,
              jointType: g.JointType.round,
              startCap: g.Cap.roundCap,
              endCap: g.Cap.roundCap,
              patterns: widget.rutaPorCalles ? const [] : [g.PatternItem.dash(18), g.PatternItem.gap(10)],
            ),
        },
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: widget.seguir != null,
        gestureRecognizers: gestos,
      );
      return conCentrar ? Stack(children: [mapa, _botonCentrar(c)]) : mapa;
    }

    return Semantics(
      label: 'Mapa: ${widget.puntos.map((p) => p.titulo ?? p.tipo.name).join(', ')}',
      child: Stack(
        children: [
          osm.FlutterMap(
            mapController: _osm,
            options: osm.MapOptions(
              initialCenter: _ll(inicio),
              initialZoom: widget.seguir != null ? widget.zoomSeguir : widget.zoom,
              initialCameraFit: widget.seguir != null || _todos.length < 2
                  ? null
                  : osm.CameraFit.bounds(
                      bounds: osm.LatLngBounds.fromPoints([for (final p in _todos) _ll(p)]),
                      padding: widget.relleno,
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
                    osm.Polyline(
                      points: [for (final p in widget.ruta) _ll(p)],
                      color: c.primary,
                      strokeWidth: 5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                      pattern: widget.rutaPorCalles ? const osm.StrokePattern.solid() : osm.StrokePattern.dashed(segments: const [14, 9]),
                    ),
                  ],
                ),
              osm.MarkerLayer(
                markers: [
                  for (final p in widget.puntos)
                    osm.Marker(
                      key: Key('marcador-${p.tipo.name}'),
                      point: _ll(mostrados[p.tipo] ?? p.punto),
                      width: 40,
                      height: 40,
                      alignment: p.tipo == TipoPunto.elegido ? Alignment.topCenter : Alignment.center,
                      child: _Marcador(tipo: p.tipo, estilo: MapaMdr.estilo(p.tipo, c), titulo: p.titulo),
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
          if (conCentrar) _botonCentrar(c),
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
        child: Center(child: Icon(icono, color: Colors.white, size: 22)),
      ),
    );
  }
}
