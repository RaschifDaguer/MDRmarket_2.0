import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_espacios.dart';
import '../data/envio_ubicacion.dart';

/// Mantiene encendido el GPS mientras lleva un pedido y, si está apagado o
/// falta el permiso, avisa claro que lo necesita (para trazar su ruta y para
/// que el cliente lo vea) con un botón que abre los ajustes del teléfono.
class AvisoUbicacion extends ConsumerWidget {
  const AvisoUbicacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(envioUbicacionProvider);
    if (estado != EstadoGps.sinPermiso && estado != EstadoGps.gpsApagado) return const SizedBox.shrink();

    final apagado = estado == EstadoGps.gpsApagado;
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
                    child: Text(
                      apagado ? 'Enciende tu GPS para repartir' : 'Necesitamos tu ubicación para repartir',
                      style: textos.titleSmall?.copyWith(color: c.onErrorContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppEspacios.xs),
              Text(
                kIsWeb
                    ? 'Permite la ubicación en el navegador (el candado junto a la dirección): así trazamos tu '
                          'ruta y el cliente ve por dónde vas con su pedido.'
                    : apagado
                    ? 'Tu GPS está apagado. Enciéndelo para trazar tu ruta y que el cliente vea por dónde vas con su pedido.'
                    : 'Permite que MDR Market use tu ubicación para trazar tu ruta y que el cliente vea por dónde vas.',
                style: textos.bodySmall?.copyWith(color: c.onErrorContainer),
              ),
              const SizedBox(height: AppEspacios.s),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('activar-ubicacion'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.onErrorContainer,
                    foregroundColor: c.errorContainer,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => kIsWeb
                      ? ref.read(envioUbicacionProvider.notifier).reintentar()
                      : ref.read(envioUbicacionProvider.notifier).activarUbicacion(),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(kIsWeb ? 'Reintentar' : (apagado ? 'Encender GPS' : 'Dar permiso')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
