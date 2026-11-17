import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/theme/app_movimiento.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../inicio/presentation/widgets/plantilla_vista.dart';
import '../../../inicio/presentation/widgets/tarjeta_rol.dart';
import '../../../perfil/data/perfil_repository.dart';
import '../../../perfil/domain/faltante.dart';
import '../../../perfil/presentation/subir_documento_sheet.dart';
import '../../data/mi_negocio_repository.dart';
import '../../data/negocio_repository.dart';
import '../../domain/finanzas.dart';
import '../../domain/negocio.dart';

/// Portada del comerciante: estado de revisión, el negocio (abierto o
/// cerrado), lo que falta para activarlo y los números del día.
class ResumenTab extends ConsumerWidget {
  const ResumenTab({super.key, required this.negocio, required this.alIrA});

  final Negocio negocio;

  /// Cambia de pestaña (1 pedidos, 2 productos, 3 ganancias).
  final ValueChanged<int> alIrA;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faltantes = ref.watch(faltantesProvider('comerciante')).value ?? const <Faltante>[];
    final resumen = ref.watch(resumenNegocioProvider(negocio.id)).value;
    final semana = ref.watch(semanaNegocioProvider(negocio.id)).value;
    final nombre = ref.watch(authControllerProvider).value?.nombre;
    final aprobado = negocio.estado == EstadoNegocio.aprobado;

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(misNegociosProvider);
        ref.invalidate(faltantesProvider('comerciante'));
        ref.invalidate(semanaNegocioProvider(negocio.id));
        return ref.refresh(resumenNegocioProvider(negocio.id).future);
      },
      child: PlantillaVista(
        tarjeta: aprobado ? _Saludo(nombre: nombre, negocio: negocio) : _tarjetaEstado(negocio.estado),
        extra: [
          if (resumen != null && resumen.pedidosNuevos > 0)
            _AvisoNuevos(cantidad: resumen.pedidosNuevos, alVer: () => alIrA(1)),
          _TarjetaNegocio(negocio),
          if (faltantes.isNotEmpty) _TarjetaFaltantes(faltantes, activo: aprobado),
          if (resumen != null) _Hoy(resumen: resumen, alVerPedidos: () => alIrA(1), alVerGanancias: () => alIrA(3)),
          if (semana != null) _Semana(semana),
          if (resumen != null && resumen.productosSinStock > 0)
            _AvisoStock(
              cantidad: resumen.productosSinStock,
              nombres: resumen.productosAgotados,
              alRenovar: () => alIrA(2),
            ),
          if (resumen != null && resumen.pocoStock.isNotEmpty) _PocoStock(resumen: resumen, alRenovar: () => alIrA(2)),
        ],
      ),
    );
  }

  static Widget _tarjetaEstado(EstadoNegocio estado) => switch (estado) {
    EstadoNegocio.pendiente => const TarjetaRol(
      icono: Icons.hourglass_top,
      titulo: 'Negocio en revisión',
      texto:
          'Estamos revisando tus datos. Mientras tanto, ve cargando tus productos: '
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

/// "Buen día, Carlos" con el nombre de la tienda (negocio activo).
class _Saludo extends StatelessWidget {
  const _Saludo({required this.nombre, required this.negocio});

  final String? nombre;
  final Negocio negocio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final hora = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buen día' : (hora < 19 ? 'Buenas tardes' : 'Buenas noches');
    return SizedBox(
      key: const Key('saludo'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre == null ? saludo : '$saludo, $nombre',
            style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(negocio.nombre, style: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// "2 pedidos nuevos · Acéptalos antes de que se acabe el tiempo".
class _AvisoNuevos extends StatelessWidget {
  const _AvisoNuevos({required this.cantidad, required this.alVer});

  final int cantidad;
  final VoidCallback alVer;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      key: const Key('aviso-nuevos'),
      color: c.primary,
      child: ListTile(
        onTap: alVer,
        leading: Icon(Icons.notifications_active, color: c.onPrimary),
        title: Text(
          cantidad == 1 ? '1 pedido nuevo' : '$cantidad pedidos nuevos',
          style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w700),
        ),
        subtitle: Text('Acéptalos antes de que se acabe el tiempo', style: TextStyle(color: c.onPrimary)),
        trailing: Text(
          'Ver',
          style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Ventas de hoy (contra ayer) y pedidos de hoy (cuántos en camino).
class _Hoy extends StatelessWidget {
  const _Hoy({required this.resumen, required this.alVerPedidos, required this.alVerGanancias});

  final ResumenNegocio resumen;
  final VoidCallback alVerPedidos;
  final VoidCallback alVerGanancias;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final variacion = resumen.variacionVentasPct;
    final comparacion = variacion == null
        ? (resumen.hoy.ventas > 0 ? 'Ayer no vendiste' : 'Todavía sin ventas')
        : '${variacion >= 0 ? '+' : '−'}${variacion.abs().round()} % que ayer';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Numero(
            clave: 'ventas-hoy',
            titulo: 'Ventas de hoy',
            valor: Formato.bs(resumen.hoy.ventas),
            detalle: comparacion,
            colorDetalle: variacion == null ? null : (variacion >= 0 ? c.primary : c.error),
            alTocar: alVerGanancias,
          ),
        ),
        const SizedBox(width: AppEspacios.s),
        Expanded(
          child: _Numero(
            clave: 'pedidos-hoy',
            titulo: 'Pedidos hoy',
            valor: '${resumen.pedidosHoy}',
            detalle: resumen.pedidosEnCamino == 0 ? 'Ninguno en camino' : '${resumen.pedidosEnCamino} en camino',
            alTocar: alVerPedidos,
          ),
        ),
      ],
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.clave,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.alTocar,
    this.colorDetalle,
  });

  final String clave;
  final String titulo;
  final String valor;
  final String detalle;
  final Color? colorDetalle;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      key: Key(clave),
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.m - 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.bodySmall),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text(
                detalle,
                style: textos.bodySmall?.copyWith(color: colorDetalle, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Esta semana": lo vendido en total y una barra por día (últimos 7 días).
class _Semana extends StatelessWidget {
  const _Semana(this.reporte);

  final Reporte reporte;

  static const _dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    // La API solo manda los días con movimiento: se completan los 7.
    final hoy = DateTime.now();
    final porDia = {for (final p in reporte.periodos) p.periodo: p.montos.ventas};
    final dias = [
      for (var i = 6; i >= 0; i--)
        (
          dia: DateTime(hoy.year, hoy.month, hoy.day - i),
          ventas: porDia[Formato.fechaApi(DateTime(hoy.year, hoy.month, hoy.day - i))] ?? 0.0,
        ),
    ];
    final maximo = dias.fold<double>(1, (m, d) => math.max(m, d.ventas));
    final total = dias.fold<double>(0, (t, d) => t + d.ventas);

    return Card(
      key: const Key('grafico-semana'),
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta semana', style: textos.bodySmall),
            Text(
              Formato.bs(total),
              key: const Key('total-semana'),
              style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppEspacios.m),
            SizedBox(
              height: 120,
              child: Semantics(
                label:
                    'Ventas por día: ${dias.map((d) => '${Formato.fecha(d.dia)} ${Formato.bs(d.ventas)}').join(', ')}',
                child: BarChart(
                  BarChartData(
                    maxY: maximo * 1.1,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => c.inverseSurface,
                        getTooltipItem: (_, _, barra, _) =>
                            BarTooltipItem(Formato.bs(barra.toY), TextStyle(color: c.onInverseSurface, fontSize: 12)),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (valor, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(_dias[dias[valor.toInt()].dia.weekday - 1], style: textos.labelSmall),
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < dias.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: dias[i].ventas,
                              width: 18,
                              // Hoy, más fuerte.
                              color: i == dias.length - 1 ? c.primary : c.primary.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Con "reducir movimiento", sin la animación de las barras.
                  duration: AppMovimiento.activo(context) ? AppMovimiento.normal : Duration.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Productos que se están acabando, con "Renovar stock".
class _PocoStock extends StatelessWidget {
  const _PocoStock({required this.resumen, required this.alRenovar});

  final ResumenNegocio resumen;
  final VoidCallback alRenovar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Card(
      key: const Key('poco-stock'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppEspacios.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.xs, AppEspacios.m, 0),
              child: Text('Poco stock', style: textos.titleMedium),
            ),
            for (final p in resumen.pocoStock.take(5))
              ListTile(
                key: Key('poco-stock-${p.id}'),
                leading: Icon(Icons.inventory_2_outlined, color: c.tertiary),
                title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.stock == 1 ? 'Queda 1' : 'Quedan ${p.stock}'),
              ),
            if (resumen.productosPocoStock > 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m),
                child: Text('y ${resumen.productosPocoStock - 5} más', style: textos.bodySmall),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppEspacios.m, AppEspacios.xs, AppEspacios.m, AppEspacios.xs),
              child: OutlinedButton.icon(
                key: const Key('renovar-poco-stock'),
                onPressed: alRenovar,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Renovar stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
/// Si ya está [activo] (ej. se pidió un documento nuevo, como la selfie), solo
/// avisa qué falta subir.
class _TarjetaFaltantes extends ConsumerWidget {
  const _TarjetaFaltantes(this.faltantes, {this.activo = false});

  final List<Faltante> faltantes;
  final bool activo;

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
          TituloSeccion(activo ? 'Te falta subir' : 'Para activar tu negocio te falta', Icons.checklist_rtl),
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

/// "Stock insuficiente": productos que se agotaron y hay que renovar.
class _AvisoStock extends StatelessWidget {
  const _AvisoStock({required this.cantidad, required this.nombres, required this.alRenovar});

  final int cantidad;
  final List<String> nombres;
  final VoidCallback alRenovar;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final varios = cantidad == 1 ? 'producto se agotó' : 'productos se agotaron';
    return Card(
      key: const Key('aviso-stock'),
      color: c.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.production_quantity_limits, color: c.onErrorContainer),
                const SizedBox(width: AppEspacios.s),
                Expanded(
                  child: Text(
                    'Stock insuficiente: $cantidad $varios',
                    style: textos.titleSmall?.copyWith(color: c.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspacios.xs),
            Text(
              '${nombres.join(', ')}${cantidad > nombres.length ? '…' : ''}. '
              'Los clientes los ven como «Agotado». Renuévalos para seguir vendiendo.',
              style: textos.bodySmall?.copyWith(color: c.onErrorContainer),
            ),
            const SizedBox(height: AppEspacios.s),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('ir-a-renovar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: c.error,
                  foregroundColor: c.onError,
                ),
                onPressed: alRenovar,
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Renovar productos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
