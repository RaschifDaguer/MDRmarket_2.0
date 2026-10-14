/// Cómo se muestran el dinero y las fechas en toda la app.
///
/// La API manda el dinero como texto con 2 decimales ("185.00") y las fechas
/// en UTC; aquí se pasan a bolivianos y a la hora del teléfono.
abstract final class Formato {
  /// Texto o número de la API → número (0 si no se puede leer).
  static double numero(Object? valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse('${valor ?? ''}') ?? 0;
  }

  /// "Bs 1.250,50" (separador de miles con punto y decimales con coma, como en Bolivia).
  static String bs(Object? valor) {
    final n = numero(valor);
    final negativo = n < 0;
    final partes = n.abs().toStringAsFixed(2).split('.');
    final enteros = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '${negativo ? '-' : ''}Bs $enteros,${partes[1]}';
  }

  /// Fecha de la API (texto ISO en UTC) → hora local del teléfono.
  static DateTime? fechaDe(Object? valor) {
    if (valor == null) return null;
    return DateTime.tryParse('$valor')?.toLocal();
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// "09/10/2026"
  static String fecha(DateTime? f) => f == null ? '' : '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

  /// "09/10 14:30"
  static String fechaHora(DateTime? f) =>
      f == null ? '' : '${_dos(f.day)}/${_dos(f.month)} ${_dos(f.hour)}:${_dos(f.minute)}';

  /// "AAAA-MM-DD", como la piden los filtros de la API.
  static String fechaApi(DateTime f) => '${f.year}-${_dos(f.month)}-${_dos(f.day)}';

  /// "hace 5 min", "hace 2 h", o la fecha si ya pasó más de un día.
  static String hace(DateTime? f, {DateTime? ahora}) {
    if (f == null) return '';
    final diferencia = (ahora ?? DateTime.now()).difference(f);
    if (diferencia.inMinutes < 1) return 'recién';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    return fechaHora(f);
  }
}
