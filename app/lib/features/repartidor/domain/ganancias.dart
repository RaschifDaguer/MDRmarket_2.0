import '../../../core/formato/formato.dart';

/// Un día de la semana en "Mis entregas".
class DiaGanancia {
  const DiaGanancia({required this.fecha, required this.dia, required this.entregas, required this.ganado});

  final DateTime fecha;

  /// "L", "M"… (como lo manda la API).
  final String dia;
  final int entregas;
  final double ganado;
}

/// Lo que gana el repartidor (`GET /api/repartidor/ganancias`): hoy, la semana
/// (lunes a domingo) día por día, su meta del día y su calificación.
class Ganancias {
  const Ganancias({
    this.entregasHoy = 0,
    this.ganadoHoy = 0,
    this.entregasSemana = 0,
    this.ganadoSemana = 0,
    this.porDia = const [],
    this.mejorDia,
    this.metaDiaria,
    this.progresoMetaPct,
    this.calificacion,
    this.totalResenas = 0,
    this.totalEntregas = 0,
  });

  final int entregasHoy;
  final double ganadoHoy;
  final int entregasSemana;
  final double ganadoSemana;
  final List<DiaGanancia> porDia;

  /// El día de la semana en que más ganó (null si todavía no entregó nada).
  final DateTime? mejorDia;

  /// Su meta de ganancia del día (null = sin meta).
  final double? metaDiaria;

  /// % de la meta de hoy (puede pasar de 100).
  final int? progresoMetaPct;
  final double? calificacion;
  final int totalResenas;

  /// Todas las entregas que hizo desde que empezó.
  final int totalEntregas;

  static const nombresDia = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

  /// "sábado".
  String? get mejorDiaTexto => mejorDia == null ? null : nombresDia[mejorDia!.weekday - 1];

  factory Ganancias.fromJson(Map<String, dynamic> json) {
    final hoy = (json['hoy'] as Map?) ?? const {};
    final semana = (json['semana'] as Map?) ?? const {};
    DateTime? fecha(Object? v) => v == null ? null : DateTime.tryParse('$v');
    final calificacion = json['calificacion'];
    return Ganancias(
      entregasHoy: (hoy['entregas'] as num?)?.toInt() ?? 0,
      ganadoHoy: Formato.numero(hoy['ganado']),
      entregasSemana: (semana['entregas'] as num?)?.toInt() ?? 0,
      ganadoSemana: Formato.numero(semana['ganado']),
      porDia: [
        for (final d in (semana['por_dia'] as List?) ?? const [])
          DiaGanancia(
            fecha: fecha((d as Map)['fecha']) ?? DateTime(2000),
            dia: (d['dia'] as String?) ?? '',
            entregas: (d['entregas'] as num?)?.toInt() ?? 0,
            ganado: Formato.numero(d['ganado']),
          ),
      ],
      mejorDia: fecha(semana['mejor_dia']),
      metaDiaria: json['meta_diaria'] == null ? null : Formato.numero(json['meta_diaria']),
      progresoMetaPct: (json['progreso_meta_pct'] as num?)?.toInt(),
      calificacion: calificacion == null ? null : Formato.numero(calificacion),
      totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
      totalEntregas: (json['total_entregas'] as num?)?.toInt() ?? 0,
    );
  }
}
