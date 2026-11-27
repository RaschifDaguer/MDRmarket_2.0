import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/formato/formato.dart';
import '../../../core/maps/coordenada.dart';
import '../../../core/maps/mapa.dart';
import '../../../core/maps/mapas.dart';
import '../../../core/maps/ruta.dart';
import '../../../core/maps/ruta_viva.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../pedidos/domain/pedido.dart';
import '../data/envio_ubicacion.dart';
import '../data/repartidor_repository.dart';
import '../data/ruta_reparto.dart';
import 'aviso_ubicacion.dart';
import 'entregar_pin_screen.dart' show AvisoCarnet;
import 'pedido_actual_screen.dart' show abrirEnlaceProvider;

/// Deja la pantalla encendida mientras está el modo GPS. Las pruebas lo reemplazan.
final pantallaEncendidaProvider = Provider<Future<void> Function(bool)>(
  (ref) => (encendida) async {
    try {
      await WakelockPlus.toggle(enable: encendida);
    } catch (_) {} // si el teléfono no lo permite, sigue sin eso
  },
);

/// A cuántos metros del destino ya cuenta como "llegaste".
const metrosParaLlegar = 40.0;

/// "350 m" o "2,4 km".
String textoDistancia(double metros) => metros < 1000
    ? '${(metros / 10).round() * 10} m'
    : '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

/// "menos de 1 min", "8 min" o "1 h 5 min".
String textoTiempo(double segundos) {
  if (segundos < 60) return 'menos de 1 min';
  final minutos = (segundos / 60).ceil();
  return minutos < 60 ? '$minutos min' : '${minutos ~/ 60} h ${minutos % 60} min';
}

/// La hora a la que llega: "15:42".
String horaDeLlegada(double segundos, {DateTime? ahora}) {
  final llega = (ahora ?? DateTime.now()).add(Duration(seconds: segundos.round()));
  return '${llega.hour.toString().padLeft(2, '0')}:${llega.minute.toString().padLeft(2, '0')}';
}

/// El ícono de cada maniobra (como en un GPS).
IconData iconoManiobra(PasoRuta? paso) {
  if (paso == null) return Icons.navigation;
  final m = paso.modificador ?? '';
  final izquierda = m.contains('left');
  return switch (paso.tipo) {
    'arrive' => Icons.flag,
    'depart' => Icons.navigation,
    'roundabout' || 'rotary' || 'roundabout turn' || 'exit roundabout' || 'exit rotary' =>
      izquierda ? Icons.roundabout_left : Icons.roundabout_right,
    'fork' => izquierda ? Icons.fork_left : Icons.fork_right,
    'merge' => Icons.merge,
    'on ramp' || 'off ramp' => izquierda ? Icons.ramp_left : Icons.ramp_right,
    _ => switch (m) {
      'uturn' => Icons.u_turn_left,
      'sharp right' => Icons.turn_sharp_right,
      'right' => Icons.turn_right,
      'slight right' => Icons.turn_slight_right,
      'sharp left' => Icons.turn_sharp_left,
      'left' => Icons.turn_left,
      'slight left' => Icons.turn_slight_left,
      _ => Icons.straight,
    },
  };
}

/// Modo GPS del repartidor ("Cómo llegar"), dentro de la app: el mapa lo sigue
/// mientras avanza por la ruta por las calles, arriba la próxima indicación
/// ("En 150 m · Gira a la derecha hacia Av. Busch") y abajo cuánto falta, a
/// qué hora llega y los datos de la parada (la tienda o el cliente). Si se
/// sale de la ruta, la recalcula. Al llegar, el botón para recoger o entregar.
class NavegacionScreen extends ConsumerStatefulWidget {
  const NavegacionScreen({super.key});

  @override
  ConsumerState<NavegacionScreen> createState() => _NavegacionScreenState();
}

class _NavegacionScreenState extends ConsumerState<NavegacionScreen> {
  bool _cambiando = false;
  late final Future<void> Function(bool) _pantalla = ref.read(pantallaEncendidaProvider);

  @override
  void initState() {
    super.initState();
    _pantalla(true);
  }

  @override
  void dispose() {
    _pantalla(false);
    super.dispose();
  }

  Future<void> _recogido(Pedido p) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _cambiando = true);
    try {
      await ref.read(repartidorRepositoryProvider).cambiarEstado(p.id, EstadoPedido.enCamino);
      mensajero.showSnackBar(const SnackBar(content: Text('Listo: ahora te llevamos a la casa del cliente.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.errorDe('estado') ?? e.mensaje)));
    } finally {
      ref.invalidate(pedidoActualProvider);
      if (mounted) setState(() => _cambiando = false);
    }
  }

  Future<void> _llamar(String telefono) async {
    final mensajero = ScaffoldMessenger.of(context);
    final ok = await ref.read(abrirEnlaceProvider)(Uri(scheme: 'tel', path: telefono.replaceAll(' ', '')));
    if (!ok) mensajero.showSnackBar(const SnackBar(content: Text('No se pudo abrir el teléfono.')));
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoActualProvider);
    return ActualizacionAutomatica(
      // Si la tienda o el cliente cambian algo (ej. lo cancelan), se ve enseguida.
      alActualizar: () => ref.invalidate(pedidoActualProvider),
      child: pedido.when(
        skipLoadingOnRefresh: true,
        skipError: true,
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Pantalla(
          titulo: 'Cómo llegar',
          child: VistaError(error: e, alReintentar: () => ref.invalidate(pedidoActualProvider)),
        ),
        data: (p) => p == null
            ? Pantalla(
                titulo: 'Cómo llegar',
                child: EstadoVacio(
                  icono: Icons.check_circle_outline,
                  titulo: 'Ya no tienes un pedido en curso',
                  texto: 'Lo entregaste, lo soltaste o lo cancelaron.',
                  accion: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => context.go('/inicio'),
                    child: const Text('Ir al inicio'),
                  ),
                ),
              )
            : _guiar(p),
      ),
    );
  }

  Widget _guiar(Pedido p) {
    final c = Theme.of(context).colorScheme;
    // Mantiene el GPS encendido (y manda la ubicación al cliente).
    ref.watch(envioUbicacionProvider);
    final yo = ref.watch(miUbicacionProvider);
    final rutaViva = ref.watch(rutaRepartoProvider);
    final recogido = p.estado == EstadoPedido.enCamino;
    final tienda = p.negocioUbicacion;
    final casa = p.destino;

    return Scaffold(
      body: ListenableBuilder(
        listenable: rutaViva,
        builder: (context, _) {
          final guia = _Guia.de(p, yo, rutaViva);
          return Stack(
            children: [
              Positioned.fill(
                child: Mapas.disponibles
                    ? MapaMdr(
                        key: const Key('mapa-navegacion'),
                        puntos: [
                          if (tienda != null && !recogido) PuntoMapa(TipoPunto.tienda, tienda, titulo: p.negocioNombre),
                          if (casa != null) PuntoMapa(TipoPunto.casa, casa, titulo: p.clienteNombre ?? 'Cliente'),
                          if (yo != null) PuntoMapa(TipoPunto.repartidor, yo, titulo: 'Tú'),
                        ],
                        ruta: rutaViva.lineaRestante,
                        rutaPorCalles: rutaViva.ruta?.porCalles ?? false,
                        seguir: yo,
                        relleno: const EdgeInsets.fromLTRB(40, 190, 40, 320),
                      )
                    : ColoredBox(color: c.surfaceContainer),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacios.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Indicacion(guia: guia, pedido: p, alSalir: () => context.pop()),
                      const SizedBox(height: AppEspacios.s),
                      const AvisoUbicacion(),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _Detalle(
                  pedido: p,
                  guia: guia,
                  cambiando: _cambiando,
                  alRecoger: () => _recogido(p),
                  alEntregar: () => context.push('/repartidor/entregar'),
                  alLlamar: _llamar,
                  alSalir: () => context.pop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lo que se muestra en el modo GPS, calculado de la ruta y la posición.
class _Guia {
  const _Guia({
    required this.recogido,
    this.paso,
    this.metrosAlPaso,
    this.metrosParada,
    this.segundosParada,
    this.segundosTotal,
    this.llego = false,
    this.buscandoGps = false,
    this.calculando = false,
    this.recalculando = false,
    this.porCalles = true,
  });

  final bool recogido;
  final PasoRuta? paso;
  final double? metrosAlPaso;

  /// Hasta la próxima parada (la tienda o la casa).
  final double? metrosParada;
  final double? segundosParada;

  /// Hasta la casa del cliente (pasando por la tienda si todavía no lo recogió).
  final double? segundosTotal;
  final bool llego;
  final bool buscandoGps;
  final bool calculando;
  final bool recalculando;
  final bool porCalles;

  static _Guia de(Pedido p, Coordenada? yo, RutaViva viva) {
    final recogido = p.estado == EstadoPedido.enCamino;
    final parada = recogido ? p.destino : p.negocioUbicacion;
    final ruta = viva.ruta;
    final avance = viva.avance;
    if (yo == null) return _Guia(recogido: recogido, buscandoGps: true);
    final enLineaRecta = parada == null ? null : Ruta.metrosEntre(yo, parada);
    if (ruta == null || avance == null) {
      return _Guia(
        recogido: recogido,
        calculando: true,
        metrosParada: enLineaRecta,
        llego: enLineaRecta != null && enLineaRecta <= metrosParaLlegar,
      );
    }
    final metros = ruta.metrosFaltan(avance, tramo: 0);
    final paso = ruta.proximoPaso(avance);
    return _Guia(
      recogido: recogido,
      paso: paso,
      metrosAlPaso: paso == null ? null : ruta.metrosHastaPaso(avance, paso),
      metrosParada: metros,
      segundosParada: ruta.segundosFaltan(avance, tramo: 0),
      segundosTotal: ruta.segundosFaltan(avance),
      llego: math.min(metros, enLineaRecta ?? double.infinity) <= metrosParaLlegar,
      recalculando: viva.recalculando,
      porCalles: ruta.porCalles,
    );
  }

  /// La indicación con el nombre de la parada al llegar.
  String instruccion(Pedido p) {
    if (llego) return recogido ? 'Llegaste a la casa de ${p.clienteNombre ?? 'el cliente'}' : 'Llegaste a ${p.negocioNombre}';
    final paso = this.paso;
    if (paso == null) return recogido ? 'Sigue hacia la casa del cliente' : 'Sigue hacia ${p.negocioNombre}';
    if (paso.esLlegada) {
      return paso.tramo == 0 && !recogido ? 'Llegas a ${p.negocioNombre}' : 'Llegas a la casa de ${p.clienteNombre ?? 'el cliente'}';
    }
    return paso.instruccion;
  }
}

/// Arriba: la próxima indicación, grande (como en un GPS).
class _Indicacion extends StatelessWidget {
  const _Indicacion({required this.guia, required this.pedido, required this.alSalir});

  final _Guia guia;
  final Pedido pedido;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (icono, arriba, abajo) = guia.buscandoGps
        ? (Icons.gps_not_fixed, 'Buscando tu ubicación…', 'Activa el GPS para trazar tu ruta.')
        : guia.calculando
        ? (Icons.alt_route, 'Calculando la ruta…', guia.metrosParada == null ? null : 'A ${textoDistancia(guia.metrosParada!)} en línea recta')
        : (
            guia.llego ? Icons.flag : iconoManiobra(guia.paso),
            guia.llego || guia.metrosAlPaso == null ? null : 'En ${textoDistancia(guia.metrosAlPaso!)}',
            null,
          );
    return Semantics(
      liveRegion: true,
      child: Material(
        key: const Key('indicacion-gps'),
        color: c.primary,
        elevation: 4,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m - 4, AppEspacios.xs, AppEspacios.m - 4),
          child: Row(
            children: [
              Icon(icono, color: c.onPrimary, size: 42),
              const SizedBox(width: AppEspacios.m - 4),
              Expanded(
                child: _TextoIndicacion(guia: guia, arriba: arriba, abajo: abajo, pedido: pedido),
              ),
              IconButton(
                key: const Key('salir-gps'),
                tooltip: 'Salir del modo GPS',
                onPressed: alSalir,
                icon: Icon(Icons.close, color: c.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextoIndicacion extends StatelessWidget {
  const _TextoIndicacion({required this.guia, required this.pedido, this.arriba, this.abajo});

  final _Guia guia;
  final String? arriba;
  final String? abajo;
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final principal = guia.buscandoGps || guia.calculando ? arriba! : guia.instruccion(pedido);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!guia.buscandoGps && !guia.calculando && arriba != null)
          Text(arriba!, key: const Key('distancia-al-paso'), style: textos.headlineSmall?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700)),
        Text(
          principal,
          key: const Key('texto-indicacion'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textos.titleMedium?.copyWith(color: c.onPrimary),
        ),
        if (abajo != null) Text(abajo!, style: textos.bodySmall?.copyWith(color: c.onPrimary.withValues(alpha: 0.85))),
        if (guia.recalculando)
          Text('Recalculando la ruta…', key: const Key('recalculando'), style: textos.bodySmall?.copyWith(color: c.onPrimary)),
        if (!guia.porCalles && !guia.calculando && !guia.buscandoGps)
          Text(
            'Ruta aproximada: ahora no pudimos calcularla por las calles.',
            style: textos.bodySmall?.copyWith(color: c.onPrimary.withValues(alpha: 0.85)),
          ),
      ],
    );
  }
}

/// Abajo: cuánto falta, a qué hora llega y los datos de la parada.
class _Detalle extends StatelessWidget {
  const _Detalle({
    required this.pedido,
    required this.guia,
    required this.cambiando,
    required this.alRecoger,
    required this.alEntregar,
    required this.alLlamar,
    required this.alSalir,
  });

  final Pedido pedido;
  final _Guia guia;
  final bool cambiando;
  final VoidCallback alRecoger;
  final VoidCallback alEntregar;
  final ValueChanged<String> alLlamar;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final p = pedido;
    final recogido = guia.recogido;
    final telefono = recogido ? p.clienteTelefono : p.negocioTelefono;
    final efectivo = p.metodoPago == 'efectivo';

    return Material(
      key: const Key('detalle-gps'),
      color: c.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.m, AppEspacios.m, AppEspacios.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cuánto falta.
                if (guia.segundosParada != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Con letra grande o "menos de 1 min", se achica en vez de salirse.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            textoTiempo(guia.segundosParada!),
                            key: const Key('tiempo-gps'),
                            maxLines: 1,
                            style: textos.headlineMedium?.copyWith(color: c.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppEspacios.s),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${textoDistancia(guia.metrosParada!)} · llegas ${horaDeLlegada(guia.segundosParada!)}',
                            key: const Key('distancia-gps'),
                            style: textos.titleSmall,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    guia.buscandoGps ? 'Esperando tu GPS…' : 'Calculando el tiempo…',
                    style: textos.titleMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                if (!recogido && guia.segundosTotal != null)
                  Text(
                    'Hasta la tienda. Entrega estimada en la casa del cliente: ${horaDeLlegada(guia.segundosTotal!)}',
                    key: const Key('entrega-estimada'),
                    style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                const SizedBox(height: AppEspacios.s),
                // La parada.
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: recogido ? Colors.red.shade700 : Colors.orange.shade800,
                      child: Icon(recogido ? Icons.person : Icons.storefront, color: Colors.white),
                    ),
                    const SizedBox(width: AppEspacios.m - 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recogido ? 'Entregar a ${p.clienteNombre ?? 'el cliente'}' : 'Recoger en ${p.negocioNombre}',
                            key: const Key('parada-gps'),
                            style: textos.titleMedium,
                          ),
                          Text(
                            [
                              recogido ? p.direccionEntrega : (p.negocioDireccion ?? 'La tienda'),
                              if (recogido && p.referenciaEntrega != null) 'Ref.: ${p.referenciaEntrega}',
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text('#${p.id}', style: textos.labelLarge?.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
                if (recogido) ...[
                  const SizedBox(height: AppEspacios.s),
                  Text(
                    efectivo ? 'Cobras ${Formato.bs(p.total)} en efectivo' : 'No cobras nada: pagó con QR',
                    key: const Key('cobro-gps'),
                    style: textos.titleSmall?.copyWith(color: efectivo ? c.tertiary : c.onSurfaceVariant),
                  ),
                  if (p.soloMayores) ...[const SizedBox(height: AppEspacios.xs), const AvisoCarnet()],
                ],
                if (p.notas != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppEspacios.xs),
                    child: Text('Nota: ${p.notas}', maxLines: 2, overflow: TextOverflow.ellipsis, style: textos.bodySmall),
                  ),
                const SizedBox(height: AppEspacios.m - 4),
                if (guia.llego)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppEspacios.s),
                    child: recogido
                        ? BotonPrincipal(
                            key: const Key('gps-entregar'),
                            texto: 'Entregar con el PIN',
                            icono: Icons.pin_outlined,
                            onPressed: alEntregar,
                          )
                        : BotonPrincipal(
                            key: const Key('gps-recogido'),
                            texto: 'Ya lo recogí',
                            icono: Icons.inventory_2_outlined,
                            cargando: cambiando,
                            onPressed: p.estado == EstadoPedido.listo ? alRecoger : null,
                          ),
                  ),
                Row(
                  children: [
                    if (telefono != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('gps-llamar'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: () => alLlamar(telefono),
                          icon: const Icon(Icons.phone_outlined),
                          label: Text(
                            'Llamar',
                            semanticsLabel: recogido ? 'Llamar al cliente' : 'Llamar a la tienda',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppEspacios.s),
                    ],
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: alSalir,
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Ver pedido'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
