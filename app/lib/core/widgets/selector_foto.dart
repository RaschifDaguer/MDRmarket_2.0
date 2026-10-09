import 'package:flutter/material.dart';

import '../archivos/archivo_elegido.dart';
import '../theme/app_espacios.dart';
import '../theme/app_movimiento.dart';

/// Recuadro para elegir una foto. Vacío muestra un ícono y [texto]; con foto
/// muestra la vista previa y un botón para cambiarla. [error] se ve en rojo debajo.
class SelectorFoto extends StatelessWidget {
  const SelectorFoto({
    super.key,
    required this.valor,
    required this.alElegir,
    required this.texto,
    this.icono = Icons.add_a_photo_outlined,
    this.error,
    this.alto = 168,
  });

  final ArchivoElegido? valor;
  final ValueChanged<ArchivoElegido> alElegir;
  final String texto;
  final IconData icono;
  final String? error;
  final double alto;

  Future<void> _elegir() async {
    final foto = await elegirFoto();
    if (foto != null) alElegir(foto);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final colorBorde = error != null ? c.error : c.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: valor == null ? texto : '$texto: cambiar foto',
          child: Material(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadios.campo),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _elegir,
              child: AnimatedContainer(
                duration: AppMovimiento.activo(context) ? AppMovimiento.normal : Duration.zero,
                height: alto,
                decoration: BoxDecoration(
                  border: Border.all(color: colorBorde, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadios.campo),
                ),
                child: valor == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icono, size: 36, color: c.primary),
                          const SizedBox(height: AppEspacios.s),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m),
                            child: Text(texto, textAlign: TextAlign.center, style: textos.bodyMedium),
                          ),
                          Text('Toca para elegir una foto',
                              style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(valor!.bytes, fit: BoxFit.cover),
                          Positioned(
                            right: AppEspacios.s,
                            bottom: AppEspacios.s,
                            child: Chip(
                              avatar: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Cambiar'),
                              backgroundColor: c.surface.withValues(alpha: 0.92),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppEspacios.xs + 2, left: AppEspacios.m - 4),
            child: Text(error!, style: textos.bodySmall?.copyWith(color: c.error)),
          ),
      ],
    );
  }
}
