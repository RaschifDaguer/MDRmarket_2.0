import 'dart:math' as math;

/// Un punto del mapa. La app usa este tipo propio en vez del de Google Maps
/// para que el resto del código no dependa del proveedor del mapa.
class Coordenada {
  const Coordenada(this.latitud, this.longitud);

  final double latitud;
  final double longitud;

  /// Plaza 24 de Septiembre: centro de Santa Cruz y punto de partida del mapa.
  static const centroSantaCruz = Coordenada(-17.78373, -63.18214);

  /// Distancia en línea recta, en km (fórmula del haversine).
  double distanciaKm(Coordenada otra) {
    const radioTierra = 6371.0;
    double rad(double g) => g * math.pi / 180;
    final dLat = rad(otra.latitud - latitud);
    final dLng = rad(otra.longitud - longitud);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitud)) * math.cos(rad(otra.latitud)) * math.pow(math.sin(dLng / 2), 2);
    return radioTierra * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String get texto => '${latitud.toStringAsFixed(5)}, ${longitud.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) => other is Coordenada && other.latitud == latitud && other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);
}
