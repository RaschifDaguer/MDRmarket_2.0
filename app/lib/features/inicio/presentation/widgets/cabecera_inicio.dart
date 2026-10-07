import 'package:flutter/material.dart';

import '../../../../core/theme/app_colores.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/usuario.dart';

/// Cabecera de la pantalla de inicio: iniciales, saludo, vista actual y el
/// botón de cerrar sesión. Si se pasa [selector], va debajo del saludo.
class CabeceraInicio extends StatelessWidget {
  const CabeceraInicio({
    super.key,
    required this.usuario,
    required this.vista,
    required this.alCerrarSesion,
    this.selector,
  });

  final Usuario usuario;
  final Vista vista;
  final VoidCallback alCerrarSesion;
  final Widget? selector;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return CabeceraFlotante(
      altura: selector == null ? 116 : 184,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppEspacios.m + 4, AppEspacios.s, AppEspacios.s + 4, AppEspacios.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Aparecer(child: _Iniciales(usuario)),
                  const SizedBox(width: AppEspacios.m - 2),
                  Expanded(
                    child: Aparecer(
                      orden: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hola, ${usuario.nombre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textos.titleLarge?.copyWith(color: Colors.white),
                          ),
                          Text(
                            'Vista ${vista.etiqueta.toLowerCase()}',
                            style: textos.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    onPressed: alCerrarSesion,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              if (selector != null) ...[
                const SizedBox(height: AppEspacios.m),
                Padding(
                  padding: const EdgeInsets.only(right: AppEspacios.s),
                  child: Aparecer(orden: 2, child: selector!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculo blanco con las iniciales del nombre y apellido.
class _Iniciales extends StatelessWidget {
  const _Iniciales(this.usuario);

  final Usuario usuario;

  String get _texto => [usuario.nombre, usuario.apellido]
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((s) => s.characters.first.toUpperCase())
      .take(2)
      .join();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColores.blanco, AppColores.fondoSuave],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Text(
        _texto,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColores.primario,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
