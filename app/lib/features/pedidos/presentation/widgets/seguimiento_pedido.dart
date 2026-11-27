import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/maps/coordenada.dart';
import '../../../../core/maps/mapa.dart';
import '../../../../core/maps/mapas.dart';
import '../../../../core/maps/mapas_repository.dart';
import '../../../../core/maps/ruta.dart';
import '../../../../core/maps/ruta_viva.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido.dart';
import '../../domain/seguimiento.dart';

/// Dibuja el mapa del seguimiento con la línea del recorrido ([porCalles]
/// = sigue las calles; si no, es recta).
typedef MapaDelSeguimiento = Widget Function(Seguimiento seguimiento, List<Coordenada> ruta, bool porCalles);

/// Cómo se dibuja el mapa del seguimiento (Google Maps con clave, si no
/// OpenStreetMap). Null = sin mapa (en las pruebas): se muestra solo el texto
/// con la distancia y el tiempo. Las pruebas lo reemplazan por un mapa falso.
final mapaSeguimientoProvider = Provider<MapaDelSeguimiento?>(
  (ref) => Mapas.disponibles
      ? (s, ruta, porCalles) => MapaSeguimiento(seguimiento: s, ruta: ruta, porCalles: porCalles)
      : null,
);

/// Cada cuánto se vuelve a preguntar dónde está el repartidor (él la manda
/// cada 4 s mientras se mueve). Entre una y otra, la moto avanza sola en el mapa.
const intervaloSeguimiento = Duration(seconds: 4);

/// "Llega en unos 8 min": mapa con el negocio, el cliente y el repartidor (o
/// el texto, si no hay mapa) que se actualiza solo mientras el pedido va en
/// camino, con la ruta por las calles. [alCambiarEstado] avisa si el pedido
/// cambió (ej. ya se entregó).
class SeguimientoPedido extends ConsumerStatefulWidget {
  const SeguimientoPedido({super.key, required this.pedidoId, required this.estado, this.alCambiarEstado});

  final int pedidoId;

  /// Estado que muestra la pantalla; si el seguimiento trae otro, se avisa.
  final EstadoPedido estado;
  final VoidCallback? alCambiarEstado;

  @override
  ConsumerState<SeguimientoPedido> createState() => _SeguimientoPedidoState();
}

class _SeguimientoPedidoState extends ConsumerState<SeguimientoPedido> {
  Timer? _reloj;
  String? _vehiculo;

  /// La ruta por las calles desde donde va el repartidor (se recalcula si se desvía).
  late final _ruta = RutaViva(
    pedir: (puntos) => ref.read(mapasRepositoryProvider).ruta(puntos, vehiculo: vehiculoParaRuta(_vehiculo)),
  );

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(intervaloSeguimiento, (_) => ref.invalidate(seguimientoProvider(widget.pedidoId)));
    ref.listenManual(seguimientoProvider(widget.pedidoId), (_, nuevo) {
      final s = nuevo.value;
      if (s == null) return;
      if (s.estado != widget.estado) widget.alCambiarEstado?.call();
      _vehiculo = s.vehiculo;
      _ruta.actualizar(
        origen: s.repartidor,
        paradas: [if (s.estado != EstadoPedido.enCamino) s.negocio, s.destino],
      );
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _ruta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seguimiento = ref.watch(seguimientoProvider(widget.pedidoId)).value;
    final mapa = ref.watch(mapaSeguimientoProvider);
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    if (seguimiento == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppEspacios.l),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _ruta,
      builder: (context, _) {
        final recogido = seguimiento.estado == EstadoPedido.enCamino;
        // Con la ruta por las calles, lo que falta de verdad; si no, lo que calcula la API.
        final ruta = _ruta.ruta;
        final avance = _ruta.avance;
        final porCalles = ruta != null && ruta.porCalles && avance != null && seguimiento.repartidor != null;
        final llega = porCalles ? (ruta.segundosFaltan(avance) / 60).ceil().clamp(1, 999) : seguimiento.tiempoMin;
        final km = porCalles ? ruta.metrosFaltan(avance) / 1000 : seguimiento.distanciaKm;
        // Ya llegó a la casa (o está en la tienda): con el margen del error del GPS.
        final rep = seguimiento.repartidor;
        final enLaCasa = recogido && rep != null && Ruta.metrosEntre(rep, seguimiento.destino) <= metrosParaLlegar;
        final enLaTienda = !recogido && rep != null && Ruta.metrosEntre(rep, seguimiento.negocio) <= metrosParaLlegar;
        final titulo = enLaCasa
            ? '¡Tu repartidor llegó!'
            : enLaTienda
            ? 'Tu repartidor está en ${seguimiento.negocioNombre}'
            : llega == null
            ? 'Esperando la ubicación del repartidor…'
            : 'Llega en unos $llega min';
        return Card(
          key: const Key('seguimiento'),
          color: enLaCasa ? c.primaryContainer : null,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mapa != null)
                SizedBox(height: 260, child: mapa(seguimiento, _ruta.lineaRestante, ruta?.porCalles ?? false)),
              ListTile(
                leading: Icon(enLaCasa ? Icons.where_to_vote : Icons.two_wheeler, color: c.primary, size: 32),
                title: Text(titulo, key: const Key('tiempo-estimado'), style: textos.titleMedium),
                subtitle: Text(
                  [
                    if (enLaCasa)
                      'Sal a recibirlo y dale tu PIN de entrega'
                    else if (enLaTienda)
                      'Está recogiendo tu pedido'
                    else ...[
                      if (km != null) 'A ${km.toStringAsFixed(1).replaceAll('.', ',')} km',
                      recogido ? 'ya lo recogió' : 'pasa primero por ${seguimiento.negocioNombre}',
                    ],
                    if (seguimiento.haceSegundos != null) 'actualizado ${_hace(seguimiento.haceSegundos!)}',
                  ].join(' · '),
                  key: const Key('distancia-seguimiento'),
                  style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ),
              if (mapa == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppEspacios.m, 0, AppEspacios.m, AppEspacios.m - 4),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, size: 16, color: c.onSurfaceVariant),
                      const SizedBox(width: AppEspacios.xs + 2),
                      Expanded(
                        child: Text(
                          'El mapa no está disponible en este dispositivo.',
                          style: textos.labelSmall?.copyWith(color: c.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _hace(int segundos) => segundos < 60 ? 'hace $segundos s' : 'hace ${segundos ~/ 60} min';
}

/// Mapa con la tienda, el cliente (una persona) y el repartidor (la moto),
/// con la ruta por las calles de lo que le falta. Cada posición nueva llega
/// cada pocos segundos (`GET /api/pedidos/{id}/seguimiento`) y la moto avanza
/// hasta ella de forma continua, sin saltos; la cámara no se mueve salvo que
/// algún punto quede fuera de la vista (o se toque "Centrar").
class MapaSeguimiento extends StatelessWidget {
  const MapaSeguimiento({super.key, required this.seguimiento, this.ruta, this.porCalles = false});

  final Seguimiento seguimiento;

  /// La línea que falta; si no se pasa, una recta (moto → tienda → casa).
  final List<Coordenada>? ruta;
  final bool porCalles;

  @override
  Widget build(BuildContext context) {
    final s = seguimiento;
    final recogido = s.estado == EstadoPedido.enCamino;
    return MapaMdr(
      key: const Key('mapa-seguimiento'),
      puntos: [
        PuntoMapa(TipoPunto.tienda, s.negocio, titulo: s.negocioNombre),
        PuntoMapa(TipoPunto.casa, s.destino, titulo: 'Tú'),
        if (s.repartidor != null)
          PuntoMapa(TipoPunto.repartidor, s.repartidor!, titulo: s.repartidorNombre ?? 'Repartidor'),
      ],
      ruta: ruta ?? [?s.repartidor, if (!recogido) s.negocio, s.destino],
      rutaPorCalles: porCalles,
      // Casi lo que tarda la siguiente posición: avanza sin pausas.
      deslizarDurante: intervaloSeguimiento - const Duration(milliseconds: 300),
    );
  }
}
