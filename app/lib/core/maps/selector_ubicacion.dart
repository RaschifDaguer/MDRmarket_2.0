import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_espacios.dart';
import 'coordenada.dart';
import 'mapa.dart';
import 'mapas.dart';
import 'mapas_repository.dart';

/// Busca la dirección escrita de un punto. Las pruebas lo reemplazan.
final buscarDireccionProvider = Provider<Future<DireccionEncontrada?> Function(Coordenada)>(
  (ref) => ref.watch(mapasRepositoryProvider).direccion,
);

/// Elegir un punto: tocando el mapa (con Google Maps también arrastrando el
/// marcador) o con el botón "Usar mi ubicación" (GPS). Sin clave de Google se
/// usa OpenStreetMap; solo en las pruebas no hay mapa y queda el GPS.
///
/// Debajo muestra la calle y el barrio del punto (no las coordenadas) y avisa
/// con [alEncontrarDireccion] para llenar el campo "Dirección".
class SelectorUbicacion extends ConsumerStatefulWidget {
  const SelectorUbicacion({
    super.key,
    required this.valor,
    required this.alCambiar,
    this.error,
    this.alEncontrarDireccion,
  });

  final Coordenada? valor;
  final ValueChanged<Coordenada> alCambiar;
  final String? error;
  final ValueChanged<DireccionEncontrada>? alEncontrarDireccion;

  /// Espera desde el último toque (o arrastre) antes de buscar la dirección.
  static const espera = Duration(milliseconds: 600);

  @override
  ConsumerState<SelectorUbicacion> createState() => _SelectorUbicacionState();
}

class _SelectorUbicacionState extends ConsumerState<SelectorUbicacion> {
  bool _buscando = false;
  String? _errorGps;
  Timer? _espera;
  bool _buscandoDireccion = false;
  DireccionEncontrada? _direccion;
  Coordenada? _deLaDireccion;
  bool _sinDireccion = false;

  @override
  void initState() {
    super.initState();
    if (widget.valor != null) _buscarDireccion(widget.valor!, esperar: false);
  }

  @override
  void didUpdateWidget(covariant SelectorUbicacion anterior) {
    super.didUpdateWidget(anterior);
    final valor = widget.valor;
    if (valor != null && valor != anterior.valor && valor != _deLaDireccion) _buscarDireccion(valor);
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  void _buscarDireccion(Coordenada punto, {bool esperar = true}) {
    _espera?.cancel();
    _buscandoDireccion = true;
    _sinDireccion = false;
    if (esperar) setState(() {}); // al abrir (initState) todavía no se puede redibujar
    _espera = Timer(esperar ? SelectorUbicacion.espera : Duration.zero, () async {
      DireccionEncontrada? encontrada;
      try {
        encontrada = await ref.read(buscarDireccionProvider)(punto);
      } catch (_) {
        encontrada = null; // sin servicio: se escribe a mano
      }
      // Si mientras tanto marcó otro punto, esta respuesta ya no sirve.
      if (!mounted || widget.valor != punto) return;
      setState(() {
        _buscandoDireccion = false;
        _direccion = encontrada;
        _deLaDireccion = punto;
        _sinDireccion = encontrada == null;
      });
      if (encontrada != null) widget.alEncontrarDireccion?.call(encontrada);
    });
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
      Position posicion;
      try {
        posicion = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
        );
      } on TimeoutException {
        // Bajo techo el GPS tarda: la última posición conocida del teléfono.
        final ultima = await Geolocator.getLastKnownPosition();
        if (ultima == null) throw 'El GPS no responde. Sal a un lugar abierto o marca el punto en el mapa.';
        posicion = ultima;
      }
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
        const SizedBox(height: AppEspacios.s),
        _LugarMarcado(
          marcado: valor != null,
          buscando: _buscandoDireccion,
          direccion: _deLaDireccion == valor ? _direccion : null,
          sinDireccion: _sinDireccion,
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

/// Debajo del mapa: la calle y el barrio del punto marcado (o que se está buscando).
class _LugarMarcado extends StatelessWidget {
  const _LugarMarcado({required this.marcado, required this.buscando, this.direccion, this.sinDireccion = false});

  final bool marcado;
  final bool buscando;
  final DireccionEncontrada? direccion;
  final bool sinDireccion;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final (icono, texto, detalle) = !marcado
        ? (Icons.location_searching, 'Ubicación sin marcar', null)
        : buscando && direccion == null
        ? (Icons.travel_explore, 'Buscando la dirección…', null)
        : direccion != null
        ? (Icons.place, direccion!.corta, direccion!.ciudad)
        : (
            Icons.place,
            'Ubicación marcada en el mapa',
            sinDireccion ? 'No encontramos el nombre de la calle: escríbela abajo.' : null,
          );
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const Key('lugar-marcado'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: marcado ? c.primary : c.onSurfaceVariant),
          const SizedBox(width: AppEspacios.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: textos.bodyMedium?.copyWith(fontWeight: marcado ? FontWeight.w600 : null)),
                if (detalle != null)
                  Text(detalle, style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          if (buscando) const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
