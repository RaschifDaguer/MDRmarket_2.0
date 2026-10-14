import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../data/mi_negocio_repository.dart';
import '../data/negocio_repository.dart';
import '../domain/negocio.dart';

/// Busca el negocio del usuario y arma la pantalla con él (o muestra que
/// está cargando, el error o que no tiene negocio).
class ConNegocio extends ConsumerWidget {
  const ConNegocio({super.key, required this.titulo, required this.builder});

  final String titulo;
  final Widget Function(Negocio negocio) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(negocioActualProvider).when(
          loading: () => Pantalla(titulo: titulo, child: const Center(child: CircularProgressIndicator())),
          error: (e, _) => Pantalla(
            titulo: titulo,
            child: VistaError(error: e, alReintentar: () => ref.invalidate(misNegociosProvider)),
          ),
          data: (negocio) => negocio == null
              ? Pantalla(
                  titulo: titulo,
                  child: const EstadoVacio(icono: Icons.storefront_outlined, titulo: 'Todavía no tienes un negocio'),
                )
              : builder(negocio),
        );
  }
}
