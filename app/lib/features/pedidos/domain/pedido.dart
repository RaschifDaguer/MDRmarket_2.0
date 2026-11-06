import 'package:flutter/material.dart';

import '../../../core/formato/formato.dart';

/// Estados de un pedido, con cómo se muestran y cómo se llama el botón que
/// lleva a ese estado (para el comerciante).
enum EstadoPedido {
  pendiente('Esperando al negocio', 'Pendiente', Icons.hourglass_top),
  confirmado('Aceptado', 'Aceptar', Icons.thumb_up_alt_outlined),
  preparando('Preparando', 'Empezar a preparar', Icons.soup_kitchen_outlined),
  listo('Listo', 'Marcar como listo', Icons.inventory_2_outlined),
  enCamino('En camino', 'Salió a entregar', Icons.delivery_dining_outlined),
  entregado('Entregado', 'Entregar (pedir PIN)', Icons.check_circle_outline),
  cancelado('Cancelado', 'Cancelar', Icons.cancel_outlined),
  rechazado('Rechazado', 'Rechazar', Icons.block);

  const EstadoPedido(this.texto, this.accion, this.icono);

  final String texto;

  /// Texto del botón que lleva a este estado.
  final String accion;
  final IconData icono;

  /// Como lo manda la API ("en_camino").
  String get api => this == enCamino ? 'en_camino' : name;

  bool get terminado => this == entregado || this == cancelado || this == rechazado;
  bool get fallido => this == cancelado || this == rechazado;

  /// Pasos del camino normal, para la línea de avance.
  static const camino = [pendiente, confirmado, preparando, listo, enCamino, entregado];

  static EstadoPedido desde(String? valor) =>
      EstadoPedido.values.firstWhere((e) => e.api == valor, orElse: () => pendiente);
}

class ItemPedido {
  const ItemPedido({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    required this.cantidad,
    required this.subtotal,
    this.imagenUrl,
    this.notas,
  });

  final int productoId;
  final String nombre;
  final double precioUnitario;
  final int cantidad;
  final double subtotal;
  final String? imagenUrl;
  final String? notas;

  factory ItemPedido.fromJson(Map<String, dynamic> json) => ItemPedido(
        productoId: (json['producto_id'] as num).toInt(),
        nombre: json['nombre'] as String,
        precioUnitario: Formato.numero(json['precio_unitario']),
        cantidad: (json['cantidad'] as num).toInt(),
        subtotal: Formato.numero(json['subtotal']),
        imagenUrl: json['imagen_url'] as String?,
        notas: json['notas'] as String?,
      );
}

/// Lo que el comprador ya calificó de un pedido entregado.
class MiResena {
  const MiResena({required this.estrellas, this.comentario, this.productoId});

  final int estrellas;
  final String? comentario;
  final int? productoId;

  factory MiResena.fromJson(Map<String, dynamic> json) => MiResena(
        estrellas: (json['estrellas'] as num).toInt(),
        comentario: json['comentario'] as String?,
        productoId: (json['producto_id'] as num?)?.toInt(),
      );
}

class Pedido {
  const Pedido({
    required this.id,
    required this.estado,
    required this.negocioId,
    required this.negocioNombre,
    required this.direccionEntrega,
    required this.subtotal,
    required this.costoEnvio,
    required this.tarifaServicio,
    required this.total,
    required this.metodoPago,
    this.negocioLogo,
    this.negocioTelefono,
    this.clienteNombre,
    this.clienteTelefono,
    this.referenciaEntrega,
    this.latitudEntrega,
    this.longitudEntrega,
    this.notas,
    this.estadoPago = 'pendiente',
    this.codigoEntrega,
    this.distanciaKm,
    this.motivoCancelacion,
    this.totalItems,
    this.items = const [],
    this.historial = const [],
    this.acciones = const [],
    this.resenaNegocio,
    this.resenasProductos = const [],
    this.creado,
    this.entregado,
    this.repartidorNombre,
    this.repartidorTelefono,
    this.repartidorVehiculo,
    this.repartidorPlaca,
    this.tamano,
  });

  final int id;
  final EstadoPedido estado;
  final int negocioId;
  final String negocioNombre;
  final String? negocioLogo;
  final String? negocioTelefono;

  /// Solo lo ve el negocio.
  final String? clienteNombre;
  final String? clienteTelefono;

  final String direccionEntrega;
  final String? referenciaEntrega;
  final double? latitudEntrega;
  final double? longitudEntrega;
  final String? notas;
  final double subtotal;
  final double costoEnvio;
  final double tarifaServicio;
  final double total;
  final String metodoPago;
  final String estadoPago;

  /// PIN de 4 números. Solo lo ve el comprador.
  final String? codigoEntrega;
  final double? distanciaKm;
  final String? motivoCancelacion;
  final int? totalItems;
  final List<ItemPedido> items;

  /// Cambios de estado con su fecha.
  final List<({EstadoPedido estado, DateTime? fecha, String? motivo})> historial;

  /// Estados a los que puede pasarlo quien lo está viendo.
  final List<EstadoPedido> acciones;
  final MiResena? resenaNegocio;
  final List<MiResena> resenasProductos;
  final DateTime? creado;
  final DateTime? entregado;

  /// Quién lo lleva (null si nadie lo aceptó o lo entrega el propio negocio).
  final String? repartidorNombre;
  final String? repartidorTelefono;

  /// Ej. "Moto" y "1234-ABC".
  final String? repartidorVehiculo;
  final String? repartidorPlaca;

  /// Tamaño de vehículo que necesita: Liviano, Mediano o Grande.
  final String? tamano;

  bool get tieneRepartidor => repartidorNombre != null;

  /// "Moto · 1234-ABC" (solo lo que tenga).
  String get vehiculoTexto => [?repartidorVehiculo, ?repartidorPlaca].join(' · ');

  int get unidades => totalItems ?? items.fold(0, (t, i) => t + i.cantidad);

  String get metodoPagoTexto => switch (metodoPago) {
        'qr' => 'Pago con QR',
        'transferencia' => 'Transferencia',
        'tarjeta' => 'Tarjeta',
        _ => 'Efectivo al recibir',
      };

  /// Cuándo pasó a [e] (null si todavía no).
  DateTime? fechaDe(EstadoPedido e) => historial.where((h) => h.estado == e).firstOrNull?.fecha;

  MiResena? resenaDe(int productoId) => resenasProductos.where((r) => r.productoId == productoId).firstOrNull;

  factory Pedido.fromJson(Map<String, dynamic> json) {
    final negocio = (json['negocio'] as Map?) ?? const {};
    final cliente = json['cliente'] as Map?;
    final repartidor = json['repartidor'] as Map?;
    final resenas = json['mis_resenas'] as Map?;
    return Pedido(
      id: json['id'] as int,
      estado: EstadoPedido.desde(json['estado'] as String?),
      negocioId: (negocio['id'] as num?)?.toInt() ?? 0,
      negocioNombre: (negocio['nombre'] as String?) ?? '',
      negocioLogo: negocio['logo_url'] as String?,
      negocioTelefono: negocio['telefono'] as String?,
      clienteNombre: cliente?['nombre'] as String?,
      clienteTelefono: cliente?['telefono'] as String?,
      direccionEntrega: (json['direccion_entrega'] as String?) ?? '',
      referenciaEntrega: json['referencia_entrega'] as String?,
      latitudEntrega: (json['latitud_entrega'] as num?)?.toDouble(),
      longitudEntrega: (json['longitud_entrega'] as num?)?.toDouble(),
      notas: json['notas'] as String?,
      subtotal: Formato.numero(json['subtotal']),
      costoEnvio: Formato.numero(json['costo_envio']),
      tarifaServicio: Formato.numero(json['tarifa_servicio']),
      total: Formato.numero(json['total']),
      metodoPago: (json['metodo_pago'] as String?) ?? 'efectivo',
      estadoPago: (json['estado_pago'] as String?) ?? 'pendiente',
      codigoEntrega: json['codigo_entrega'] as String?,
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      motivoCancelacion: json['motivo_cancelacion'] as String?,
      totalItems: (json['total_items'] as num?)?.toInt(),
      items: ((json['items'] as List?) ?? const []).map((i) => ItemPedido.fromJson(i as Map<String, dynamic>)).toList(),
      historial: [
        for (final h in (json['historial'] as List?) ?? const [])
          (
            estado: EstadoPedido.desde((h as Map)['estado'] as String?),
            fecha: Formato.fechaDe(h['fecha']),
            motivo: h['motivo'] as String?,
          ),
      ],
      acciones: ((json['acciones'] as List?) ?? const []).map((a) => EstadoPedido.desde(a as String)).toList(),
      resenaNegocio: resenas?['negocio'] is Map ? MiResena.fromJson(resenas!['negocio'] as Map<String, dynamic>) : null,
      resenasProductos: ((resenas?['productos'] as List?) ?? const [])
          .map((r) => MiResena.fromJson(r as Map<String, dynamic>))
          .toList(),
      creado: Formato.fechaDe(json['created_at']),
      entregado: Formato.fechaDe(json['entregado_en']),
      repartidorNombre: repartidor?['nombre'] as String?,
      repartidorTelefono: repartidor?['telefono'] as String?,
      repartidorVehiculo: repartidor?['vehiculo'] as String?,
      repartidorPlaca: repartidor?['placa'] as String?,
      tamano: json['tamano'] as String?,
    );
  }
}
