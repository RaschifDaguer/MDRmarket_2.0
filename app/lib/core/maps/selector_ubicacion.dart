import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_espacios.dart';
import 'coordenada.dart';
import 'mapas.dart';

/// Elegir un punto: tocando el mapa, arrastrando el marcador o con el botón
/// "Usar mi ubicación" (GPS). Si el mapa no está disponible (sin clave de
/// Google), funciona solo con el GPS.
class SelectorUbicacion extends StatefulWidget {
  const SelectorUbicacion({super.key, required this.valor, required this.alCambiar, this.error});

  final Coordenada? valor;
  final ValueChanged<Coordenada> alCambiar;
  final String? error;

  @override
  State<SelectorUbicacion> createState() => _SelectorUbicacionState();
}

class _SelectorUbicacionState extends State<SelectorUbicacion> {
  GoogleMapController? _mapa;
  bool _buscando = false;
  String? _errorGps;

  @override
  void dispose() {
    _mapa?.dispose();
    super.dispose();
  }

  Future<void> _usarMiUbicacion() async {
    setState(() {
      _buscando = true;
      _errorGps = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Activa la ubicación (GPS) del dispositivo.';
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        throw 'No diste permiso para usar tu ubicación. Puedes marcarla tocando el mapa.';
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final punto = Coordenada(posicion.latitude, posicion.longitude);
      widget.alCambiar(punto);
      await _mapa?.animateCamera(CameraUpdate.newLatLngZoom(_latLng(punto), 17));
    } catch (e) {
      if (mounted) setState(() => _errorGps = e is String ? e : 'No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  static LatLng _latLng(Coordenada c) => LatLng(c.latitud, c.longitud);
  static Coordenada _coordenada(LatLng p) => Coordenada(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final valor = widget.valor;
    final error = widget.error ?? _errorGps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (Mapas.disponibles) ...[
          Text('Toca el mapa (o arrastra el marcador) donde está tu negocio.',
              style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: AppEspacios.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadios.campo),
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: widget.error != null ? c.error : c.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadios.campo),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _latLng(valor ?? Coordenada.centroSantaCruz),
                  zoom: valor == null ? 13 : 16,
                ),
                onMapCreated: (control) => _mapa = control,
                onTap: (punto) => widget.alCambiar(_coordenada(punto)),
                markers: {
                  if (valor != null)
                    Marker(
                      markerId: const MarkerId('punto'),
                      position: _latLng(valor),
                      draggable: true,
                      onDragEnd: (punto) => widget.alCambiar(_coordenada(punto)),
                    ),
                },
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                // Dentro de un formulario con scroll, el mapa se queda con el gesto.
                gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
              ),
            ),
          ),
          const SizedBox(height: AppEspacios.s),
        ] else
          Container(
            padding: const EdgeInsets.all(AppEspacios.m - 2),
            decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadios.campo),
              border: Border.all(color: widget.error != null ? c.error : c.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.map_outlined, color: c.onSurfaceVariant),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  child: Text(
                    'El mapa no está disponible en este dispositivo. Usa el botón de GPS '
                    'estando en tu negocio.',
                    style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppEspacios.s),
        OutlinedButton.icon(
          onPressed: _buscando ? null : _usarMiUbicacion,
          icon: _buscando
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: const Text('Usar mi ubicación'),
        ),
        const SizedBox(height: AppEspacios.xs),
        Text(
          valor == null ? 'Ubicación sin marcar' : '📍 ${valor.texto}',
          textAlign: TextAlign.center,
          style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppEspacios.xs + 2, left: AppEspacios.m - 4),
            child: Text(error, style: textos.bodySmall?.copyWith(color: c.error)),
          ),
      ],
    );
  }
}
