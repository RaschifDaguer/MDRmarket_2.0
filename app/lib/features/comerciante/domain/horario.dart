/// Un tramo del horario de atención: un día de la semana de "08:00" a "20:00".
class Horario {
  const Horario({required this.diaSemana, required this.apertura, required this.cierre});

  /// 1 = lunes … 7 = domingo.
  final int diaSemana;
  final String apertura;
  final String cierre;

  static const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  String get dia => dias[diaSemana - 1];

  factory Horario.fromJson(Map<String, dynamic> json) => Horario(
        diaSemana: (json['dia_semana'] as num).toInt(),
        apertura: json['hora_apertura'] as String,
        cierre: json['hora_cierre'] as String,
      );

  Map<String, dynamic> toJson() => {'dia_semana': diaSemana, 'hora_apertura': apertura, 'hora_cierre': cierre};
}
