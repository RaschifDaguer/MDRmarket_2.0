import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../inicio/presentation/widgets/plantilla_vista.dart';
import '../../../inicio/presentation/widgets/tarjeta_rol.dart';
import '../../../perfil/data/perfil_repository.dart';
import '../../../perfil/domain/faltante.dart';
import '../../../perfil/presentation/subir_documento_sheet.dart';
import '../../data/mi_negocio_repository.dart';
import '../../data/negocio_repository.dart';
import '../../domain/negocio.dart';

/// Portada del comerciante: estado de revisión, el negocio (abierto o
/// cerrado), lo que falta para activarlo y los números del día.
class ResumenTab extends ConsumerWidget {
  const ResumenTab({super.key, required this.negocio, required this.alIrA});

  final Negocio negocio;

  /// Cambia de pestaña (1 productos, 2 pedidos, 3 ganancias).
  final ValueChanged<int> alIrA;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faltantes = ref.watch(faltantesProvider('comerciante')).value ?? const <Faltante>[];
    final resumen = ref.watch(resumenNegocioProvider(negocio.id)).value;

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(misNegociosProvider);
        ref.invalidate(faltantesProvider('comerciante'));
        return ref.refresh(resumenNegocioProvider(negocio.id).future);
      },
      child: PlantillaVista(
        tarjeta: _tarjetaEstado(negocio.estado),
        extra: [
          _TarjetaNegocio(negocio),
          if (faltantes.isNotEmpty) _TarjetaFaltantes(faltantes),
          if (resumen != null)
            _Numeros(
              celdas: [
                _Celda('Pedidos nuevos', '${resumen.pedidosNuevos}', Icons.notifications_active_outlined,
                    destacar: resumen.pedidosNuevos > 0, alTocar: () => alIrA(2)),
                _Celda('En curso', '${resumen.pedidosEnCurso}', Icons.delivery_dining_outlined, alTocar: () => alIrA(2)),
                _Celda('Ventas de hoy', Formato.bs(resumen.hoy.ventas), Icons.point_of_sale_outlined, alTocar: () => alIrA(3)),
                _Celda('Ganancia del mes', Formato.bs(resumen.mes.gananciaNeta), Icons.trending_up, alTocar: () => alIrA(3)),
                _Celda('Productos activos', '${resumen.productosActivos}', Icons.inventory_2_outlined, alTocar: () => alIrA(1)),
                _Celda('Sin stock', '${resumen.productosSinStock}', Icons.production_quantity_limits,
                    destacar: resumen.productosSinStock > 0, alTocar: () => alIrA(1)),
              ],
            ),
        ],
      ),
    );
  }

  static Widget _tarjetaEstado(EstadoNegocio estado) => switch (estado) {
        EstadoNegocio.pendiente => const TarjetaRol(
            icono: Icons.hourglass_top,
            titulo: 'Negocio en revisión',
            texto: 'Estamos revisando tus datos. Mientras tanto, ve cargando tus productos: '
                'aparecerán en el catálogo cuando tu negocio esté activo.',
            tono: TonoRol.espera,
          ),
        EstadoNegocio.aprobado => const TarjetaRol(
            icono: Icons.storefront_outlined,
            titulo: '¡Tu negocio está activo!',
            texto: 'Tus productos ya aparecen en el catálogo y puedes recibir pedidos.',
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

/// Foto, nombre, rubro, dirección, estado y el interruptor abierto/cerrado.
class _TarjetaNegocio extends ConsumerStatefulWidget {
  const _TarjetaNegocio(this.negocio);

  final Negocio negocio;

  @override
  ConsumerState<_TarjetaNegocio> createState() => _TarjetaNegocioState();
}

class _TarjetaNegocioState extends ConsumerState<_TarjetaNegocio> {
  bool _cambiando = false;

  Future<void> _abrirCerrar(bool abierto) async {
    setState(() => _cambiando = true);
    try {
      await ref.read(miNegocioRepositoryProvider).abierto(widget.negocio.id, abierto);
      ref.invalidate(misNegociosProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final negocio = widget.negocio;
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final aprobado = negocio.estado == EstadoNegocio.aprobado;

    return Tarjeta3D(
      inclinacionMax: 4,
      child: Column(
        children: [
          Row(
            children: [
              ImagenRed(negocio.logoUrl, ancho: 76, alto: 76, radio: 18, icono: Icons.storefront),
              const SizedBox(width: AppEspacios.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(negocio.nombre, style: textos.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (negocio.categoria != null) Text(negocio.categoria!.etiqueta, style: textos.bodyMedium),
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
          const Divider(height: AppEspacios.l),
          // La tarjeta 3D no es "Material": sin esto el efecto al tocar no se ve.
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('interruptor-abierto'),
              contentPadding: EdgeInsets.zero,
              value: negocio.abierto,
              onChanged: _cambiando ? null : _abrirCerrar,
              title: Text(negocio.abierto ? 'Abierto: recibiendo pedidos' : 'Cerrado: no recibe pedidos'),
              subtitle: const Text('Ciérralo cuando no puedas atender.'),
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

class _Celda {
  const _Celda(this.titulo, this.valor, this.icono, {this.destacar = false, required this.alTocar});

  final String titulo;
  final String valor;
  final IconData icono;
  final bool destacar;
  final VoidCallback alTocar;
}

/// Cuadritos con los números del negocio (2 o 3 por fila según el ancho).
class _Numeros extends StatelessWidget {
  const _Numeros({required this.celdas});

  final List<_Celda> celdas;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, limites) {
      final columnas = limites.maxWidth > 480 ? 3 : 2;
      final ancho = (limites.maxWidth - (columnas - 1) * AppEspacios.s) / columnas;
      return Wrap(
        spacing: AppEspacios.s,
        runSpacing: AppEspacios.s,
        children: [
          for (final celda in celdas)
            SizedBox(
              width: ancho,
              child: Card(
                color: celda.destacar ? c.primaryContainer : null,
                child: InkWell(
                  onTap: celda.alTocar,
                  child: Padding(
                    padding: const EdgeInsets.all(AppEspacios.m - 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(celda.icono, color: c.primary),
                        const SizedBox(height: AppEspacios.s),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(celda.valor, style: textos.titleLarge),
                        ),
                        Text(celda.titulo, style: textos.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
