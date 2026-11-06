import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_espacios.dart';
import '../data/envio_ubicacion.dart';

/// Mantiene encendido el envío del GPS mientras lleva un pedido y, si no dio
/// permiso de ubicación, avisa claro que lo necesita para repartir.
class AvisoUbicacion extends ConsumerWidget {
  const AvisoUbicacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(envioUbicacionProvider) != EstadoGps.sinPermiso) return const SizedBox.shrink();

    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacios.m),
      child: Card(
        key: const Key('aviso-ubicacion'),
        color: c.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.m - 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.location_off_outlined, color: c.onErrorContainer),
                  const SizedBox(width: AppEspacios.s + 2),
                  Expanded(
                    child: Text('Necesitamos tu ubicación para repartir',
                        style: textos.titleSmall?.copyWith(color: c.onErrorContainer)),
                  ),
                ],
              ),
              const SizedBox(height: AppEspacios.xs),
              Text(
                'Activa el GPS y permite que MDR Market use tu ubicación: así el cliente ve por dónde vas con su pedido.',
                style: textos.bodySmall?.copyWith(color: c.onErrorContainer),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: c.onErrorContainer),
                  onPressed: () => ref.read(envioUbicacionProvider.notifier).enviar(),
                  child: const Text('Reintentar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
