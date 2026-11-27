import 'dart:math' as math;

import '../formato/formato.dart';
import 'coordenada.dart';

/// A cuántos metros de la tienda o de la casa ya cuenta como "llegó". El GPS
/// de un celular se equivoca de 20 a 50 m (más bajo techo) y el punto que el
/// cliente marcó en el mapa también puede estar corrido unos metros.
const metrosParaLlegar = 70.0;

/// Una indicación del GPS: "Gira a la derecha hacia Av. Busch".
class PasoRuta {
  const PasoRuta({
    required this.instruccion,
    required this.tipo,
    required this.punto,
    required this.indice,
    this.modificador,
    this.calle,
    this.distanciaM = 0,
    this.tramo = 0,
  });

  final String instruccion;

  /// Tipo de maniobra de OSRM (turn, depart, arrive, roundabout…).
  final String tipo;

  /// Hacia dónde (right, left, straight, uturn…).
  final String? modificador;
  final String? calle;
  final double distanciaM;

  /// Dónde está la maniobra.
  final Coordenada punto;

  /// En qué punto de [Ruta.puntos] está la maniobra.
  final int indice;

  /// 0 = hasta la primera parada (ej. la tienda); 1 = de ahí a la siguiente.
  final int tramo;

  bool get esLlegada => tipo == 'arrive';

  factory PasoRuta.fromJson(Map<String, dynamic> j) => PasoRuta(
    instruccion: (j['instruccion'] as String?) ?? '',
    tipo: (j['tipo'] as String?) ?? 'turn',
    modificador: j['modificador'] as String?,
    calle: j['calle'] as String?,
    distanciaM: Formato.numero(j['distancia_m']),
    punto: Coordenada(Formato.numero(j['latitud']), Formato.numero(j['longitud'])),
    indice: (j['indice'] as num?)?.toInt() ?? 0,
    tramo: (j['tramo'] as num?)?.toInt() ?? 0,
  );
}

/// Dónde va uno sobre la ruta.
class AvanceRuta {
  const AvanceRuta({
    required this.segmento,
    required this.proyectado,
    required this.recorridoM,
    required this.fueraM,
  });

  /// Está entre `puntos[segmento]` y `puntos[segmento + 1]`.
  final int segmento;

  /// El punto de la ruta más cercano a uno.
  final Coordenada proyectado;

  /// Metros de ruta ya recorridos (desde el inicio hasta [proyectado]).
  final double recorridoM;

  /// A cuántos metros de la ruta está (si es mucho, se salió y hay que recalcular).
  final double fueraM;
}

/// Ruta por las calles (`GET /api/mapas/ruta`), o una línea recta si el
/// servicio de rutas no respondió ([porCalles] = false).
class Ruta {
  Ruta({
    required this.puntos,
    required this.distanciaM,
    required this.duracionS,
    this.pasos = const [],
    List<int>? finDeTramos,
    this.porCalles = true,
  }) : finDeTramos = finDeTramos ?? [math.max(0, puntos.length - 1)],
       _acumulado = _acumular(puntos);

  final List<Coordenada> puntos;
  final double distanciaM;
  final double duracionS;
  final List<PasoRuta> pasos;

  /// En qué punto termina cada tramo (la tienda, la casa…).
  final List<int> finDeTramos;
  final bool porCalles;

  /// Metros desde el inicio hasta cada punto.
  final List<double> _acumulado;

  /// Velocidad promedio de una moto en la ciudad (la de la API), para la línea recta.
  static const velocidadRectaKmh = 25.0;

  factory Ruta.fromJson(Map<String, dynamic> j) {
    final puntos = [
      for (final p in (j['puntos'] as List? ?? const []))
        Coordenada(Formato.numero((p as List)[0]), Formato.numero(p[1])),
    ];
    return Ruta(
      puntos: puntos,
      distanciaM: Formato.numero(j['distancia_m']),
      duracionS: Formato.numero(j['duracion_s']),
      pasos: [for (final p in (j['pasos'] as List? ?? const [])) PasoRuta.fromJson(p as Map<String, dynamic>)],
      finDeTramos: [
        for (final t in (j['tramos'] as List? ?? const [])) ((t as Map)['indice_fin'] as num?)?.toInt() ?? 0,
      ],
    );
  }

  /// Sin servicio de rutas: línea recta entre los puntos (como antes), con el
  /// tiempo a la velocidad promedio.
  factory Ruta.recta(List<Coordenada> puntos) {
    final acumulado = _acumular(puntos);
    final metros = acumulado.isEmpty ? 0.0 : acumulado.last;
    return Ruta(
      puntos: puntos,
      distanciaM: metros,
      duracionS: metros / 1000 / velocidadRectaKmh * 3600,
      finDeTramos: [for (var i = 1; i < puntos.length; i++) i],
      porCalles: false,
    );
  }

  static List<double> _acumular(List<Coordenada> puntos) {
    final acumulado = <double>[];
    for (var i = 0; i < puntos.length; i++) {
      acumulado.add(i == 0 ? 0 : acumulado[i - 1] + metrosEntre(puntos[i - 1], puntos[i]));
    }
    return acumulado;
  }

  static double metrosEntre(Coordenada a, Coordenada b) => a.distanciaKm(b) * 1000;

  /// Metros desde el inicio hasta el punto [indice].
  double metrosHasta(int indice) => _acumulado.isEmpty ? 0 : _acumulado[indice.clamp(0, _acumulado.length - 1)];

  /// Dónde está [yo] sobre la ruta: el punto más cercano de la línea.
  AvanceRuta avance(Coordenada yo) {
    if (puntos.length < 2) {
      return AvanceRuta(
        segmento: 0,
        proyectado: puntos.firstOrNull ?? yo,
        recorridoM: 0,
        fueraM: puntos.isEmpty ? 0 : metrosEntre(yo, puntos.first),
      );
    }
    // Plano local en metros (alcanza para unos km dentro de la ciudad).
    final metrosPorGradoLat = 111320.0;
    final metrosPorGradoLng = 111320.0 * math.cos(yo.latitud * math.pi / 180);
    double x(Coordenada c) => (c.longitud - yo.longitud) * metrosPorGradoLng;
    double y(Coordenada c) => (c.latitud - yo.latitud) * metrosPorGradoLat;

    var mejor = 0;
    var mejorT = 0.0;
    var menor = double.infinity;
    for (var i = 0; i < puntos.length - 1; i++) {
      final ax = x(puntos[i]), ay = y(puntos[i]);
      final dx = x(puntos[i + 1]) - ax, dy = y(puntos[i + 1]) - ay;
      final largo2 = dx * dx + dy * dy;
      // Uno está en (0, 0): el punto del segmento más cercano al origen.
      final t = largo2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / largo2).clamp(0.0, 1.0);
      final px = ax + t * dx, py = ay + t * dy;
      final d = px * px + py * py;
      if (d < menor) {
        (menor, mejor, mejorT) = (d, i, t);
      }
    }
    final a = puntos[mejor], b = puntos[mejor + 1];
    final proyectado = Coordenada(
      a.latitud + (b.latitud - a.latitud) * mejorT,
      a.longitud + (b.longitud - a.longitud) * mejorT,
    );
    return AvanceRuta(
      segmento: mejor,
      proyectado: proyectado,
      recorridoM: _acumulado[mejor] + metrosEntre(a, proyectado),
      fueraM: math.sqrt(menor),
    );
  }

  /// Lo que falta de la línea, desde donde va (para dibujarla: lo recorrido desaparece).
  List<Coordenada> restante(AvanceRuta a) => [a.proyectado, ...puntos.skip(a.segmento + 1)];

  /// En qué tramo va (0 = hacia la primera parada).
  int tramoDe(AvanceRuta a) {
    for (var t = 0; t < finDeTramos.length; t++) {
      if (a.segmento < finDeTramos[t]) return t;
    }
    return math.max(0, finDeTramos.length - 1);
  }

  /// Metros que faltan hasta el final del tramo [tramo] (o de toda la ruta).
  double metrosFaltan(AvanceRuta a, {int? tramo}) {
    final fin = tramo == null ? distanciaTotalLinea : metrosHasta(finDeTramos[tramo.clamp(0, finDeTramos.length - 1)]);
    return math.max(0, fin - a.recorridoM);
  }

  /// Segundos que faltan (a la velocidad de esta ruta).
  double segundosFaltan(AvanceRuta a, {int? tramo}) =>
      metrosFaltan(a, tramo: tramo) * (distanciaTotalLinea <= 0 ? 0 : duracionS / distanciaTotalLinea);

  /// Largo de la línea dibujada (puede diferir un poco de [distanciaM]).
  double get distanciaTotalLinea => _acumulado.isEmpty ? 0 : _acumulado.last;

  /// La próxima indicación (la primera maniobra que todavía está adelante).
  PasoRuta? proximoPaso(AvanceRuta a) {
    for (final p in pasos) {
      if (p.indice > a.segmento && p.tipo != 'depart') return p;
    }
    return pasos.where((p) => p.esLlegada).lastOrNull;
  }

  /// Metros hasta la maniobra [paso].
  double metrosHastaPaso(AvanceRuta a, PasoRuta paso) => math.max(0, metrosHasta(paso.indice) - a.recorridoM);
}
