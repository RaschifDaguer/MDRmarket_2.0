/// Un punto del mapa. La app usa este tipo propio en vez del de Google Maps
/// para que el resto del código no dependa del proveedor del mapa.
class Coordenada {
  const Coordenada(this.latitud, this.longitud);

  final double latitud;
  final double longitud;

  /// Plaza 24 de Septiembre: centro de Santa Cruz y punto de partida del mapa.
  static const centroSantaCruz = Coordenada(-17.78373, -63.18214);

  String get texto => '${latitud.toStringAsFixed(5)}, ${longitud.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is Coordenada && other.latitud == latitud && other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);
}
