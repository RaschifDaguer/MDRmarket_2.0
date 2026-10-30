import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/usuario.dart';
import '../../../perfil/data/perfil_repository.dart';
import '../../../repartidor/data/repartidor_repository.dart';
import '../../../repartidor/presentation/faltantes_repartidor.dart';
import '../../../repartidor/presentation/vista_repartidor.dart';
import '../widgets/plantilla_vista.dart';
import '../widgets/tarjeta_rol.dart';

/// Vista repartidor. Mientras la solicitud no esté aprobada, muestra su estado
/// y lo que le falta subir.
class InicioRepartidor extends ConsumerWidget {
  const InicioRepartidor({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (usuario.estadoRepartidor) {
      // Aprobado: en línea, pedidos disponibles, su pedido en curso y sus entregas.
      'aprobado' => const VistaRepartidor(),
      'suspendido' => const PlantillaVista(
          tarjeta: TarjetaRol(
            icono: Icons.block,
            titulo: 'Cuenta de repartidor suspendida',
            texto: 'Comunícate con soporte para más información.',
            tono: TonoRol.alerta,
          ),
        ),
      'rechazado' => _rechazado(context, ref),
      _ => _enRevision(ref),
    };
  }

  /// En revisión: lo que falta subir o, si ya subió todo, que espere al administrador.
  Widget _enRevision(WidgetRef ref) {
    // Mientras carga (o si falla) solo se ve la tarjeta del estado.
    final faltantes = ref.watch(faltantesProvider('repartidor')).value;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(faltantesProvider('repartidor').future),
      child: PlantillaVista(
        tarjeta: TarjetaRol(
          icono: Icons.hourglass_top,
          titulo: 'Solicitud en revisión',
          texto: faltantes != null && faltantes.isNotEmpty
              ? 'Sube lo que te falta para que podamos revisar tu solicitud.'
              : 'Estamos revisando tus documentos. Te avisaremos cuando puedas empezar a repartir.',
          tono: TonoRol.espera,
        ),
        extra: [
          if (faltantes != null) faltantes.isEmpty ? const TodoEnviado() : FaltantesRepartidor(faltantes),
        ],
      ),
    );
  }

  /// Rechazado: el motivo y el botón para volver a enviar la solicitud.
  Widget _rechazado(BuildContext context, WidgetRef ref) {
    final motivo = ref.watch(miRepartidorProvider).value?.motivoRechazo;
    return PlantillaVista(
      tarjeta: TarjetaRol(
        icono: Icons.block,
        titulo: 'Solicitud no aprobada',
        texto: motivo ?? 'Revisa tus datos y vuelve a enviar tu solicitud.',
        tono: TonoRol.alerta,
      ),
      extra: [
        FilledButton.icon(
          onPressed: () => context.go('/registrar-repartidor'),
          icon: const Icon(Icons.refresh),
          label: const Text('Volver a enviar'),
        ),
      ],
    );
  }
}
