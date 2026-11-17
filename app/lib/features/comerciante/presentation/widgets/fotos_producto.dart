import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/archivos/archivo_elegido.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/mi_producto.dart';

/// Cómo se elige una foto (la galería). En las pruebas se reemplaza.
final elegirFotoProvider = Provider<Future<ArchivoElegido?> Function()>(
  (_) =>
      () => elegirFoto(),
);

/// Hasta 4 fotos del producto: las que ya tiene ([subidas], al editar) y las
/// nuevas que eligió ([nuevas]). La primera es la portada.
class FotosProducto extends ConsumerWidget {
  const FotosProducto({
    super.key,
    required this.subidas,
    required this.nuevas,
    required this.alAgregar,
    required this.alQuitarNueva,
    this.alQuitarSubida,
    this.alHacerPortada,
    this.error,
  });

  static const maximo = 4;

  final List<FotoProducto> subidas;
  final List<ArchivoElegido> nuevas;
  final ValueChanged<ArchivoElegido> alAgregar;
  final ValueChanged<int> alQuitarNueva;
  final ValueChanged<FotoProducto>? alQuitarSubida;
  final ValueChanged<FotoProducto>? alHacerPortada;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final total = subidas.length + nuevas.length;
    // La portada es la que el servidor marcó; si todavía no hay, la primera nueva.
    final hayPortada = subidas.any((f) => f.portada);

    Widget marco({required Widget child, required bool portada, Key? key, List<Widget> botones = const []}) => SizedBox(
      key: key,
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
          ),
          if (portada)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(8)),
                child: Text('Portada', style: textos.labelSmall?.copyWith(color: c.onPrimary)),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(mainAxisSize: MainAxisSize.min, children: botones),
          ),
        ],
      ),
    );

    Widget boton(IconData icono, String ayuda, VoidCallback alTocar, {Key? key}) => Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: c.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        child: IconButton(
          key: key,
          tooltip: ayuda,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: Icon(icono),
          onPressed: alTocar,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppEspacios.s,
          runSpacing: AppEspacios.s,
          children: [
            for (final f in subidas)
              marco(
                key: Key('foto-subida-${f.id}'),
                portada: f.portada,
                child: ImagenRed(f.url, ancho: 92, alto: 92, radio: 14),
                botones: [
                  if (!f.portada && alHacerPortada != null)
                    boton(Icons.star_outline, 'Usar de portada', () => alHacerPortada!(f), key: Key('portada-${f.id}')),
                  if (alQuitarSubida != null)
                    boton(Icons.close, 'Quitar foto', () => alQuitarSubida!(f), key: Key('quitar-foto-${f.id}')),
                ],
              ),
            for (var i = 0; i < nuevas.length; i++)
              marco(
                key: Key('foto-nueva-$i'),
                portada: !hayPortada && i == 0,
                child: Image.memory(nuevas[i].bytes, fit: BoxFit.cover, width: 92, height: 92),
                botones: [boton(Icons.close, 'Quitar foto', () => alQuitarNueva(i), key: Key('quitar-nueva-$i'))],
              ),
            if (total < maximo)
              Semantics(
                button: true,
                label: 'Agregar foto',
                child: Material(
                  color: c.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: error != null ? c.error : c.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('agregar-foto'),
                    onTap: () async {
                      final foto = await ref.read(elegirFotoProvider)();
                      if (foto != null) alAgregar(foto);
                    },
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: c.primary),
                          const SizedBox(height: 4),
                          Text(total == 0 ? 'Portada' : 'Foto', style: textos.labelMedium),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppEspacios.xs),
        Text(
          error ?? 'Hasta $maximo fotos ($total de $maximo). Con buena luz se vende más.',
          key: const Key('fotos-ayuda'),
          style: textos.bodySmall?.copyWith(color: error != null ? c.error : c.onSurfaceVariant),
        ),
      ],
    );
  }
}
