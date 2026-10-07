import 'package:flutter/material.dart';

import '../../../../core/theme/app_colores.dart';
import '../../../../core/theme/app_movimiento.dart';
import '../../../auth/domain/usuario.dart';

/// Ícono de cada vista (el mismo que usaba el menú anterior).
IconData iconoDeVista(Vista v) => switch (v) {
      Vista.cliente => Icons.shopping_bag_outlined,
      Vista.repartidor => Icons.delivery_dining,
      Vista.comerciante => Icons.storefront_outlined,
    };

/// Selector de vista con una "pastilla" blanca que se desliza hasta la
/// opción elegida. Va sobre la cabecera verde.
///
/// [alElegir] hace el cambio real (la pantalla de inicio llama a la API).
/// Mientras espera, la pastilla ya se mueve y la opción muestra un círculo
/// de carga; si el cambio falla, vuelve sola a la vista actual.
class SelectorVista extends StatefulWidget {
  const SelectorVista({
    super.key,
    required this.vistas,
    required this.actual,
    required this.alElegir,
  });

  final List<Vista> vistas;
  final Vista actual;
  final Future<void> Function(Vista) alElegir;

  @override
  State<SelectorVista> createState() => _SelectorVistaState();
}

class _SelectorVistaState extends State<SelectorVista> {
  /// Vista que se tocó y todavía espera respuesta.
  Vista? _pendiente;

  Future<void> _elegir(Vista v) async {
    if (_pendiente != null || v == widget.actual) return;
    setState(() => _pendiente = v);
    try {
      await widget.alElegir(v);
    } finally {
      if (mounted) setState(() => _pendiente = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animar = AppMovimiento.activo(context);
    final duracion = animar ? AppMovimiento.normal : Duration.zero;
    final marcada = _pendiente ?? widget.actual;
    final n = widget.vistas.length;
    final indice = widget.vistas.indexOf(marcada).clamp(0, n - 1);

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          // La pastilla que se desliza.
          AnimatedAlign(
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * indice / (n - 1), 0),
            duration: duracion,
            curve: Curves.easeOutBack,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final v in widget.vistas)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: v == marcada,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _elegir(v),
                      child: _Opcion(
                        vista: v,
                        marcada: v == marcada,
                        cargando: v == _pendiente,
                        duracion: duracion,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.vista,
    required this.marcada,
    required this.cargando,
    required this.duracion,
  });

  final Vista vista;
  final bool marcada;
  final bool cargando;
  final Duration duracion;

  @override
  Widget build(BuildContext context) {
    final color = marcada ? AppColores.primario : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (cargando)
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(iconoDeVista(vista), size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: duracion,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
              child: Text(vista.etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}
