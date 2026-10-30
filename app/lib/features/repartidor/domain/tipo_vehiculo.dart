import 'package:flutter/material.dart';

/// Moto, bicicleta, auto, camioneta o camión, según `GET /api/tipos-vehiculo`.
/// Dice qué se le pide al vehículo (la bicicleta no pide placa, RUAT ni licencia).
class TipoVehiculo {
  const TipoVehiculo({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.requierePlaca = true,
    this.requiereRuat = true,
    this.requiereLicencia = true,
    this.categoria,
    this.descripcion,
  });

  final int id;

  /// 'moto', 'bicicleta', 'auto', 'camioneta' o 'camion'.
  final String codigo;
  final String nombre;
  final bool requierePlaca;
  final bool requiereRuat;
  final bool requiereLicencia;

  /// Liviano, Mediano o Grande (qué tamaño de pedidos puede llevar).
  final String? categoria;
  final String? descripcion;

  IconData get icono => iconoDe(codigo);

  static IconData iconoDe(String codigo) => switch (codigo) {
        'moto' => Icons.two_wheeler,
        'bicicleta' => Icons.pedal_bike,
        'auto' => Icons.directions_car_outlined,
        'camioneta' => Icons.airport_shuttle_outlined,
        'camion' => Icons.local_shipping_outlined,
        _ => Icons.delivery_dining_outlined,
      };

  factory TipoVehiculo.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'] as Map?;
    return TipoVehiculo(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      requierePlaca: json['requiere_placa'] == true,
      requiereRuat: json['requiere_ruat'] == true,
      requiereLicencia: json['requiere_licencia'] == true,
      categoria: categoria?['nombre'] as String?,
      descripcion: categoria?['descripcion'] as String?,
    );
  }
}
