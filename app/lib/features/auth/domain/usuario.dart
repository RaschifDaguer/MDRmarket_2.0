/// Vistas de la app. Un usuario siempre tiene `cliente`; las otras dependen
/// de si se registró como repartidor o tiene un negocio.
enum Vista {
  cliente('Cliente'),
  repartidor('Repartidor'),
  comerciante('Comerciante');

  const Vista(this.etiqueta);
  final String etiqueta;

  static Vista? desde(String? valor) {
    for (final v in Vista.values) {
      if (v.name == valor) return v;
    }
    return null;
  }
}

/// Usuario conectado, tal como lo devuelve GET /api/me.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.vistas,
    required this.vistaGuardada,
    this.apellido,
    this.telefono,
    this.ciNumero,
    this.esAdmin = false,
    this.estadoRepartidor,
  });

  final int id;
  final String nombre;
  final String? apellido;
  final String email;
  final String? telefono;
  final String? ciNumero;
  final bool esAdmin;

  /// Vistas que puede abrir (siempre incluye cliente).
  final List<Vista> vistas;

  /// Última vista que eligió (rol_activo en la base).
  final String vistaGuardada;

  /// 'pendiente', 'aprobado', 'suspendido'… o null si no es repartidor.
  final String? estadoRepartidor;

  String get nombreCompleto => [nombre, apellido].whereType<String>().join(' ');

  /// El botón "cambiar vista" solo aparece si tiene más de una.
  bool get puedeCambiarVista => vistas.length > 1;

  /// Vista en la que se abre la app. Si la guardada ya no está disponible
  /// (ej. le rechazaron la solicitud de repartidor), vuelve a cliente.
  Vista get vistaActual {
    final guardada = Vista.desde(vistaGuardada);
    return (guardada != null && vistas.contains(guardada)) ? guardada : Vista.cliente;
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as Map?) ?? const {};
    final repartidor = roles['repartidor'];
    return Usuario(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String?,
      email: json['email'] as String,
      telefono: json['telefono'] as String?,
      ciNumero: json['ci_numero'] as String?,
      esAdmin: json['es_admin'] == true,
      vistaGuardada: (json['rol_activo'] as String?) ?? 'cliente',
      vistas: ((json['vistas'] as List?) ?? const ['cliente'])
          .map((v) => Vista.desde('$v'))
          .whereType<Vista>()
          .toList(),
      estadoRepartidor: repartidor is Map ? repartidor['estado'] as String? : null,
    );
  }
}
