/// Una página de una lista larga de la API: `{data: [...], meta: {current_page, last_page, total}}`.
class Pagina<T> {
  const Pagina({required this.items, required this.pagina, required this.ultimaPagina, this.total});

  final List<T> items;
  final int pagina;
  final int ultimaPagina;

  /// Cuántos hay en total, en todas las páginas (null si la API no lo dice).
  final int? total;

  bool get hayMas => pagina < ultimaPagina;

  factory Pagina.desdeJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) {
    final meta = (json['meta'] as Map?) ?? const {};
    return Pagina(
      items: ((json['data'] as List?) ?? const []).map((e) => item(e as Map<String, dynamic>)).toList(),
      pagina: (meta['current_page'] as num?)?.toInt() ?? 1,
      ultimaPagina: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt(),
    );
  }
}
