import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/theme/app_movimiento.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/mi_negocio_repository.dart';
import '../../domain/finanzas.dart';
import '../../domain/negocio.dart';

/// Hoy, Semana (últimos 7 días) o Mes (lo que va del mes), y el período
/// anterior del mismo largo para comparar.
enum Periodo {
  hoy('Hoy', 'que ayer'),
  semana('Semana', 'que la semana pasada'),
  mes('Mes', 'que el mes pasado');

  const Periodo(this.texto, this.contra);
  final String texto;

  /// "+12 % que ayer".
  final String contra;

  (DateTime, DateTime) rango(DateTime hoy) {
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    return switch (this) {
      Periodo.hoy => (dia, dia),
      Periodo.semana => (dia.subtract(const Duration(days: 6)), dia),
      Periodo.mes => (DateTime(hoy.year, hoy.month), dia),
    };
  }

  /// El período anterior: ayer, los 7 días antes o el mes pasado hasta el mismo día.
  (DateTime, DateTime) anterior(DateTime hoy) {
    final (desde, hasta) = rango(hoy);
    return switch (this) {
      Periodo.hoy || Periodo.semana => (
        desde.subtract(Duration(days: hasta.difference(desde).inDays + 1)),
        desde.subtract(const Duration(days: 1)),
      ),
      Periodo.mes => (
        DateTime(hoy.year, hoy.month - 1),
        // El mismo día del mes pasado (o su último día, si es más corto).
        DateTime(hoy.year, hoy.month - 1, math.min(hoy.day, DateTime(hoy.year, hoy.month, 0).day)),
      ),
    };
  }
}

typedef _Consulta = ({int negocioId, Periodo periodo});
typedef DatosGanancias = ({Reporte reporte, Montos anterior, List<ReporteProducto> productos});

final gananciasProvider = FutureProvider.family<DatosGanancias, _Consulta>((ref, consulta) async {
  final repo = ref.watch(miNegocioRepositoryProvider);
  final hoy = DateTime.now();
  final (desde, hasta) = consulta.periodo.rango(hoy);
  final (antesDesde, antesHasta) = consulta.periodo.anterior(hoy);
  final (reporte, anterior, productos) = await (
    repo.reporte(consulta.negocioId, desde, hasta, 'dia'),
    repo.reporte(consulta.negocioId, antesDesde, antesHasta, 'anio'),
    repo.reporteProductos(consulta.negocioId, desde, hasta),
  ).wait;
  return (reporte: reporte, anterior: anterior.totales, productos: productos);
});

/// Ganancias: lo que le quedó limpio en el período (contra el anterior), de
/// dónde sale, el gráfico por día y lo que más se vende.
class GananciasTab extends ConsumerStatefulWidget {
  const GananciasTab({super.key, required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<GananciasTab> createState() => _GananciasTabState();
}

class _GananciasTabState extends ConsumerState<GananciasTab> {
  Periodo _periodo = Periodo.hoy;

  @override
  Widget build(BuildContext context) {
    final consulta = (negocioId: widget.negocio.id, periodo: _periodo);
    final datos = ref.watch(gananciasProvider(consulta));
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(gananciasProvider(consulta).future),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<Periodo>(
                    key: const Key('periodo-ganancias'),
                    showSelectedIcon: false,
                    segments: [for (final p in Periodo.values) ButtonSegment(value: p, label: Text(p.texto))],
                    selected: {_periodo},
                    onSelectionChanged: (s) => setState(() => _periodo = s.first),
                  ),
                  const SizedBox(height: AppEspacios.m),
                  datos.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppEspacios.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) =>
                        VistaError(error: e, alReintentar: () => ref.invalidate(gananciasProvider(consulta))),
                    data: (d) {
                      final masVendidos = [...d.productos.where((p) => p.unidadesVendidas > 0)]
                        ..sort((a, b) => b.unidadesVendidas.compareTo(a.unidadesVendidas));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Limpio(montos: d.reporte.totales, anterior: d.anterior, periodo: _periodo),
                          const SizedBox(height: AppEspacios.m),
                          _Desglose(d.reporte.totales),
                          if (d.reporte.periodos.length > 1) ...[
                            const SizedBox(height: AppEspacios.m),
                            Text('Ventas y ganancia por día', style: textos.titleMedium),
                            const SizedBox(height: AppEspacios.s),
                            _Grafico(d.reporte),
                          ],
                          const SizedBox(height: AppEspacios.m),
                          Text('Lo que más se vende', style: textos.titleMedium),
                          const SizedBox(height: AppEspacios.s),
                          if (masVendidos.isEmpty)
                            const Text('Todavía no vendiste nada en este período.')
                          else
                            Card(
                              key: const Key('mas-vendidos'),
                              child: Column(
                                children: [
                                  for (final (i, p) in masVendidos.take(5).indexed)
                                    _FilaVendido(puesto: i + 1, producto: p),
                                ],
                              ),
                            ),
                          const SizedBox(height: AppEspacios.m),
                          OutlinedButton.icon(
                            key: const Key('anotar-compra'),
                            onPressed: () => context.push('/negocio/registros'),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Anotar compra o gasto'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Te quedó limpio Bs 820 · +12 % que ayer".
class _Limpio extends StatelessWidget {
  const _Limpio({required this.montos, required this.anterior, required this.periodo});

  final Montos montos;
  final Montos anterior;
  final Periodo periodo;

  /// Comparación con el período anterior; null si antes no hubo ganancia (no hay con qué comparar).
  static String? comparacion(double ahora, double antes, String contra) {
    if (antes <= 0) return null;
    final pct = (ahora - antes) / antes * 100;
    return '${pct >= 0 ? '+' : '−'}${pct.abs().round()} % $contra';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final neto = montos.gananciaNeta;
    final texto =
        comparacion(neto, anterior.gananciaNeta, periodo.contra) ??
        (anterior.ventas == 0 ? 'Sin ventas en el período anterior' : 'Antes: ${Formato.bs(anterior.gananciaNeta)}');
    final sube = neto >= anterior.gananciaNeta;

    return Card(
      key: const Key('te-quedo-limpio'),
      color: c.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Te quedó limpio', style: textos.bodyMedium?.copyWith(color: c.onPrimaryContainer)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formato.bs(neto),
                style: textos.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: neto < 0 ? c.error : c.onPrimaryContainer,
                ),
              ),
            ),
            Row(
              children: [
                Icon(sube ? Icons.trending_up : Icons.trending_down, size: 18, color: c.onPrimaryContainer),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    texto,
                    key: const Key('comparacion'),
                    style: textos.bodySmall?.copyWith(color: c.onPrimaryContainer, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// De dónde sale: ventas − lo que costó lo vendido − gastos − comisión = ganancia.
class _Desglose extends StatelessWidget {
  const _Desglose(this.montos);

  final Montos montos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    Widget fila(String texto, double valor, {bool resta = false, bool total = false, String? ayuda}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: total ? textos.titleSmall : textos.bodyMedium),
                if (ayuda != null) Text(ayuda, style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${resta && valor > 0 ? '− ' : ''}${Formato.bs(valor)}',
            style: (total ? textos.titleMedium : textos.bodyMedium)?.copyWith(
              fontWeight: total ? FontWeight.w800 : null,
              color: resta ? c.error : (total && valor < 0 ? c.error : null),
            ),
          ),
        ],
      ),
    );

    return Card(
      key: const Key('desglose'),
      child: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: Column(
          children: [
            fila('Ventas', montos.ventas, ayuda: '${montos.unidadesVendidas} unidades vendidas'),
            fila('Lo que te costaron', montos.costoDeLoVendido, resta: true),
            fila('Gastos anotados', montos.gastos, resta: true),
            fila('Comisión de MDR Market', montos.comisiones, resta: true),
            const Divider(),
            fila('Ganancia', montos.gananciaNeta, total: true),
            if (montos.compras > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppEspacios.xs),
                child: Text(
                  'Compraste mercadería por ${Formato.bs(montos.compras)}: no se resta aquí, '
                  'se cuenta cuando la vendes (en "Lo que te costaron").',
                  style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaVendido extends StatelessWidget {
  const _FilaVendido({required this.puesto, required this.producto});

  final int puesto;
  final ReporteProducto producto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return ListTile(
      key: Key('vendido-${producto.productoId}'),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: puesto == 1 ? c.primary : c.secondaryContainer,
        child: Text(
          '$puesto',
          style: textos.labelLarge?.copyWith(color: puesto == 1 ? c.onPrimary : c.onSecondaryContainer),
        ),
      ),
      title: Text(producto.producto, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${producto.unidadesVendidas} vendidos · ganaste ${Formato.bs(producto.ganancia)}'),
      trailing: producto.margenPct == null
          ? null
          : Text('${producto.margenPct!.toStringAsFixed(0)}% margen', style: textos.labelSmall),
    );
  }
}

/// Barras por día: ventas (claro) y ganancia bruta (oscuro).
class _Grafico extends StatelessWidget {
  const _Grafico(this.reporte);

  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final maximo = reporte.periodos.fold<double>(1, (m, p) => math.max(m, p.montos.ventas));
    // "2026-10-09" → "9"
    String etiqueta(String periodo) {
      final partes = periodo.split('-');
      return partes.length == 3 ? '${int.tryParse(partes[2]) ?? partes[2]}' : periodo;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppEspacios.s, AppEspacios.m, AppEspacios.m, AppEspacios.s),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maximo * 1.15,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: c.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        // Sin el número de arriba de todo (es solo margen sobre la barra más alta).
                        getTitlesWidget: (valor, meta) => valor == meta.max
                            ? const SizedBox.shrink()
                            : SideTitleWidget(
                                meta: meta,
                                child: Text(valor.toStringAsFixed(0), style: Theme.of(context).textTheme.labelSmall),
                              ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (valor, meta) {
                          final i = valor.toInt();
                          if (i < 0 || i >= reporte.periodos.length) return const SizedBox.shrink();
                          // Con muchos días, una etiqueta cada tantos para que no se encimen.
                          final salto = (reporte.periodos.length / 10).ceil();
                          if (i % salto != 0) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              etiqueta(reporte.periodos[i].periodo),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => c.inverseSurface,
                      getTooltipItem: (grupo, _, barra, indice) => BarTooltipItem(
                        '${indice == 0 ? 'Ventas' : 'Ganancia'}\n${Formato.bs(barra.toY)}',
                        TextStyle(color: c.onInverseSurface, fontSize: 12),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < reporte.periodos.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          BarChartRodData(
                            toY: reporte.periodos[i].montos.ventas,
                            color: c.primaryContainer,
                            width: 7,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          BarChartRodData(
                            toY: math.max(0, reporte.periodos[i].montos.gananciaBruta),
                            color: c.primary,
                            width: 7,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                  ],
                ),
                // Con "reducir movimiento", sin la animación de las barras.
                duration: AppMovimiento.activo(context) ? AppMovimiento.normal : Duration.zero,
              ),
            ),
            const SizedBox(height: AppEspacios.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Leyenda(color: c.primaryContainer, texto: 'Ventas'),
                const SizedBox(width: AppEspacios.m),
                _Leyenda(color: c.primary, texto: 'Ganancia bruta'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(texto, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
