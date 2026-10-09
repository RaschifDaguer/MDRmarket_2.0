import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/usuario.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../comerciante/data/negocio_repository.dart';
import '../../../comerciante/domain/negocio.dart';
import '../../../perfil/data/perfil_repository.dart';
import '../../../perfil/domain/faltante.dart';
import '../../../perfil/presentation/subir_documento_sheet.dart';
import '../widgets/plantilla_vista.dart';
import '../widgets/tarjeta_accion.dart';
import '../widgets/tarjeta_rol.dart';
import 'aviso_proximo_modulo.dart';

/// Vista comerciante: el negocio, su estado de revisión y lo que falta para
/// activarlo. Productos, pedidos y ganancias llegan en las próximas partes.
class InicioComerciante extends ConsumerWidget {
  const InicioComerciante({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negocios = ref.watch(misNegociosProvider);
    final faltantes = ref.watch(faltantesProvider('comerciante')).value ?? const <Faltante>[];

    if (!negocios.hasValue) {
      if (negocios.hasError) {
        return PlantillaVista(
          tarjeta: TarjetaRol(
            icono: Icons.cloud_off_outlined,
            titulo: 'No se pudo cargar tu negocio',
            texto: '${negocios.error}',
            tono: TonoRol.alerta,
          ),
          extra: [
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(misNegociosProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final lista = negocios.value!;
    if (lista.isEmpty) {
      return PlantillaVista(
        tarjeta: const TarjetaRol(
          icono: Icons.storefront_outlined,
          titulo: 'Todavía no tienes un negocio',
          texto: 'Regístralo para empezar a vender.',
          tono: TonoRol.comerciante,
        ),
        extra: [
          TarjetaAccion(
            icono: Icons.add_business_outlined,
            titulo: 'Registra tu negocio',
            texto: 'Nombre, ubicación y una foto. Lo revisamos y te avisamos.',
            boton: 'Registrar mi negocio',
            alPresionar: () => context.go('/registrar-negocio'),
          ),
        ],
      );
    }

    // Por ahora se muestra el primer negocio (la base admite varios).
    final negocio = lista.first;
    return PlantillaVista(
      tarjeta: _tarjetaEstado(negocio.estado),
      extra: [
        _TarjetaNegocio(negocio),
        if (faltantes.isNotEmpty) _TarjetaFaltantes(faltantes),
      ],
      proximo: const AvisoProximoModulo(icono: Icons.inventory_2_outlined),
    );
  }

  static Widget _tarjetaEstado(EstadoNegocio estado) => switch (estado) {
        EstadoNegocio.pendiente => const TarjetaRol(
            icono: Icons.hourglass_top,
            titulo: 'Negocio en revisión',
            texto: 'Estamos revisando tus datos. Te avisaremos cuando tu negocio esté activo.',
            tono: TonoRol.espera,
          ),
        EstadoNegocio.aprobado => const TarjetaRol(
            icono: Icons.storefront_outlined,
            titulo: '¡Tu negocio está activo!',
            texto: 'Pronto podrás cargar tus productos y recibir pedidos.',
            tono: TonoRol.comerciante,
          ),
        EstadoNegocio.rechazado => const TarjetaRol(
            icono: Icons.block,
            titulo: 'Registro rechazado',
            texto: 'Revisa tus datos y documentos, o escríbenos a soporte.',
            tono: TonoRol.alerta,
          ),
        EstadoNegocio.suspendido => const TarjetaRol(
            icono: Icons.block,
            titulo: 'Negocio suspendido',
            texto: 'Comunícate con soporte para más información.',
            tono: TonoRol.alerta,
          ),
      };
}

/// Foto, nombre, rubro, dirección y estado del negocio.
class _TarjetaNegocio extends StatelessWidget {
  const _TarjetaNegocio(this.negocio);

  final Negocio negocio;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final aprobado = negocio.estado == EstadoNegocio.aprobado;

    return Tarjeta3D(
      inclinacionMax: 4,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox.square(
              dimension: 76,
              child: negocio.logoUrl == null
                  ? ColoredBox(color: c.secondaryContainer, child: Icon(Icons.storefront, color: c.onSecondaryContainer))
                  : Image.network(
                      negocio.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: c.secondaryContainer,
                        child: Icon(Icons.broken_image_outlined, color: c.onSecondaryContainer),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppEspacios.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(negocio.nombre, style: textos.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (negocio.categoria != null)
                  Text(negocio.categoria!.etiqueta, style: textos.bodyMedium),
                if (negocio.direccion != null)
                  Text(
                    negocio.direccion!,
                    style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppEspacios.s),
                Chip(
                  avatar: Icon(aprobado ? Icons.check_circle : Icons.schedule, size: 16),
                  label: Text(negocio.estado.etiqueta),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: aprobado ? c.primaryContainer : c.secondaryContainer,
                  side: BorderSide.none,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de lo que falta para activar el negocio, con un botón para resolverlo.
class _TarjetaFaltantes extends ConsumerWidget {
  const _TarjetaFaltantes(this.faltantes);

  final List<Faltante> faltantes;

  /// El tema da a los botones ancho completo; aquí van al lado del texto.
  static final _compacto = FilledButton.styleFrom(minimumSize: const Size(0, 40));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Tarjeta3D(
      inclinacionMax: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSeccion('Para activar tu negocio te falta', Icons.checklist_rtl),
          for (final f in faltantes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppEspacios.xs),
              child: Row(
                children: [
                  Icon(Icons.radio_button_unchecked, size: 18, color: c.outline),
                  const SizedBox(width: AppEspacios.s + 2),
                  Expanded(child: Text(f.texto, style: textos.bodyMedium)),
                  if (f.esDocumento)
                    FilledButton.tonalIcon(
                      style: _compacto,
                      onPressed: () async {
                        if (await mostrarSubirDocumento(context, f)) {
                          ref.invalidate(faltantesProvider('comerciante'));
                        }
                      },
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: const Text('Subir'),
                    )
                  else if (f.codigo == 'apellido' || f.codigo == 'ci_numero')
                    FilledButton.tonal(
                      style: _compacto,
                      onPressed: () => _completarDato(context, ref, f),
                      child: const Text('Completar'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Cuentas antiguas sin apellido o CI: se completa con un diálogo simple.
  Future<void> _completarDato(BuildContext context, WidgetRef ref, Faltante f) async {
    final campo = f.codigo; // 'apellido' o 'ci_numero'
    final control = TextEditingController();
    final mensajero = ScaffoldMessenger.of(context);

    final valor = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(f.texto),
        content: TextField(
          controller: control,
          autofocus: true,
          keyboardType: campo == 'ci_numero' ? TextInputType.number : TextInputType.name,
          textCapitalization: campo == 'apellido' ? TextCapitalization.words : TextCapitalization.none,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
          FilledButton(
            style: _compacto,
            onPressed: () => Navigator.pop(contexto, control.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    control.dispose();
    if (valor == null || valor.isEmpty) return;

    try {
      final usuario = await ref.read(perfilRepositoryProvider).actualizar({campo: valor});
      ref.read(authControllerProvider.notifier).actualizarUsuario(usuario);
      ref.invalidate(faltantesProvider('comerciante'));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.errorDe(campo) ?? e.mensaje)));
    }
  }
}
