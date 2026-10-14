import '../../../core/maps/coordenada.dart';

/// Dirección guardada del cliente ("Casa", "Trabajo"…).
class Direccion {
  const Direccion({
    required this.id,
    required this.direccion,
    required this.ubicacion,
    this.etiqueta,
    this.referencia,
    this.predeterminada = false,
  });

  final int id;
  final String? etiqueta;
  final String direccion;
  final String? referencia;
  final Coordenada ubicacion;
  final bool predeterminada;

  String get titulo => (etiqueta == null || etiqueta!.isEmpty) ? direccion : etiqueta!;

  factory Direccion.fromJson(Map<String, dynamic> json) => Direccion(
        id: json['id'] as int,
        etiqueta: json['etiqueta'] as String?,
        direccion: json['direccion'] as String,
        referencia: json['referencia'] as String?,
        ubicacion: Coordenada((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
        predeterminada: json['predeterminada'] == true,
      );
}

/// Costo del envío hasta una dirección.
class Cotizacion {
  const Cotizacion({required this.costoEnvio, required this.tarifaServicio, required this.distanciaKm, this.anillo});

  final double costoEnvio;
  final double tarifaServicio;
  final double distanciaKm;
  final int? anillo;

  factory Cotizacion.fromJson(Map<String, dynamic> json) => Cotizacion(
        costoEnvio: double.tryParse('${json['costo_envio']}') ?? 0,
        tarifaServicio: double.tryParse('${json['tarifa_servicio']}') ?? 0,
        distanciaKm: (json['distancia_km'] as num?)?.toDouble() ?? 0,
        anillo: (json['anillo'] as num?)?.toInt(),
      );
}
