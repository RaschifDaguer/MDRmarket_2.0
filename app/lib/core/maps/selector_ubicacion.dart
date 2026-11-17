import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_espacios.dart';
import 'coordenada.dart';
import 'mapa.dart';
import 'mapas.dart';

/// Elegir un punto: tocando el mapa (con Google Maps también arrastrando el
/// marcador) o con el botón "Usar mi ubicación" (GPS). Sin clave de Google se
/// usa OpenStreetMap; solo en las pruebas no hay mapa y queda el GPS.
class SelectorUbicacion extends StatefulWidget {
  const SelectorUbicacion({super.key, required this.valor, required this.alCambiar, this.error});

  final Coordenada? valor;
  final ValueChanged<Coordenada> alCambiar;
  final String? error;

  @override
  State<SelectorUbicacion> createState() => _SelectorUbicacionState();
}

class _SelectorUbicacionState extends State<SelectorUbicacion> {
  bool _buscando = false;
  String? _errorGps;

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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      final punto = Coordenada(posicion.latitude, posicion.longitude);
      // El mapa se centra solo en el punto nuevo.
      widget.alCambiar(punto);
    } catch (e) {
      if (mounted) setState(() => _errorGps = e is String ? e : 'No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

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
          Text('Toca el mapa en el lugar exacto.', style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: AppEspacios.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadios.campo),
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: widget.error != null ? c.error : c.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadios.campo),
              ),
              child: MapaMdr(
                key: const Key('mapa-selector'),
                puntos: [if (valor != null) PuntoMapa(TipoPunto.elegido, valor)],
                centro: valor ?? Coordenada.centroSantaCruz,
                zoom: valor == null ? 13 : 16,
                alTocar: widget.alCambiar,
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
