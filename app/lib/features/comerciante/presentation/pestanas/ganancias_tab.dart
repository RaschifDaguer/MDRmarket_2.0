import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formato/formato.dart';
import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/mi_negocio_repository.dart';
import '../../domain/finanzas.dart';
import '../../domain/negocio.dart';

/// Rango de fechas del reporte.
enum Periodo {
  hoy('Hoy', 'dia'),
  semana('7 días', 'dia'),
  mes('Este mes', 'dia'),
  anio('Este año', 'mes');

  const Periodo(this.texto, this.agrupar);
  final String texto;
  final String agrupar;

  (DateTime, DateTime) rango(DateTime hoy) => switch (this) {
        Periodo.hoy => (hoy, hoy),
        Periodo.semana => (hoy.subtract(const Duration(days: 6)), hoy),
        Periodo.mes => (DateTime(hoy.year, hoy.month), hoy),
        Periodo.anio => (DateTime(hoy.year), hoy),
      };
}

typedef _Consulta = ({int negocioId, Periodo periodo});

final _gananciasProvider = FutureProvider.family<({Reporte reporte, List<ReporteProducto> productos}), _Consulta>(
  (ref, consulta) async {
    final repo = ref.watch(miNegocioRepositoryProvider);
    final (desde, hasta) = consulta.periodo.rango(DateTime.now());
    final (reporte, productos) = await (
      repo.reporte(consulta.negocioId, desde, hasta, consulta.periodo.agrupar),
      repo.reporteProductos(consulta.negocioId, desde, hasta),
    ).wait;
    return (reporte: reporte, productos: productos);
  },
);

/// Ganancias: totales del período, gráfico por día (o mes) y por producto.
class GananciasTab extends ConsumerStatefulWidget {
  const GananciasTab({super.key, required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<GananciasTab> createState() => _GananciasTabState();
}

class _GananciasTabState extends ConsumerState<GananciasTab> {
  Periodo _periodo = Periodo.mes;

  @override
  Widget build(BuildContext context) {
    final consulta = (negocioId: widget.negocio.id, periodo: _periodo);
    final datos = ref.watch(_gananciasProvider(consulta));
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_gananciasProvider(consulta).future),
      child: ListView(
        padding: const EdgeInsets.all(AppEspacios.m),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AppEspacios.s,
                    children: [
                      for (final p in Periodo.values)
                        ChoiceChip(
                          label: Text(p.texto),
                          selected: _periodo == p,
                          onSelected: (_) => setState(() => _periodo = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppEspacios.m),
                  datos.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppEspacios.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => VistaError(error: e, alReintentar: () => ref.invalidate(_gananciasProvider(consulta))),
                    data: (d) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Totales(d.reporte.totales),
                        const SizedBox(height: AppEspacios.m),
                        if (d.reporte.periodos.length > 1) ...[
                          Text('Ventas y ganancia', style: textos.titleMedium),
                          const SizedBox(height: AppEspacios.s),
                          _Grafico(d.reporte),
                          const SizedBox(height: AppEspacios.m),
                        ],
                        Text('Por producto', style: textos.titleMedium),
                        const SizedBox(height: AppEspacios.s),
                        if (d.productos.isEmpty)
                          const Text('Todavía no hay ventas ni compras en este período.')
                        else
                          for (final p in d.productos) _FilaProducto(p),
                        const SizedBox(height: AppEspacios.m),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/negocio/registros'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Compras y gastos'),
                        ),
                      ],
                    ),
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

class _Totales extends StatelessWidget {
  const _Totales(this.montos);

  final Montos montos;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final celdas = [
      ('Ventas', montos.ventas, '${montos.unidadesVendidas} unidades vendidas', c.primary),
      ('Ganancia bruta', montos.gananciaBruta, 'Ventas − lo que te costó', c.primary),
      ('Gastos y comisiones', montos.gastos + montos.comisiones, 'Compras: ${Formato.bs(montos.compras)}', c.error),
      ('Ganancia neta', montos.gananciaNeta, 'Lo que te queda', montos.gananciaNeta < 0 ? c.error : c.primary),
    ];
    return LayoutBuilder(builder: (context, limites) {
      final columnas = limites.maxWidth > 560 ? 4 : 2;
      final ancho = (limites.maxWidth - (columnas - 1) * AppEspacios.s) / columnas;
      return Wrap(
        spacing: AppEspacios.s,
        runSpacing: AppEspacios.s,
        children: [
          for (final (titulo, valor, ayuda, color) in celdas)
            SizedBox(
              width: ancho,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacios.m - 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: Theme.of(context).textTheme.bodySmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formato.bs(valor),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(ayuda, style: Theme.of(context).textTheme.labelSmall, maxLines: 2),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Barras por período: ventas (claro) y ganancia bruta (oscuro).
class _Grafico extends StatelessWidget {
  const _Grafico(this.reporte);

  final Reporte reporte;

  String _etiqueta(String periodo) {
    // "2026-10-09" → "9" ; "2026-10" → "oct"
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final partes = periodo.split('-');
    if (partes.length == 3) return '${int.tryParse(partes[2]) ?? partes[2]}';
    if (partes.length == 2) return meses[(int.tryParse(partes[1]) ?? 1) - 1];
    return periodo;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final maximo = reporte.periodos.fold<double>(1, (m, p) => math.max(m, p.montos.ventas));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppEspacios.s, AppEspacios.m, AppEspacios.m, AppEspacios.s),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maximo * 1.15,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: c.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
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
                            child: Text(_etiqueta(reporte.periodos[i].periodo), style: Theme.of(context).textTheme.labelSmall),
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
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(texto, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto(this.p);

  final ReporteProducto p;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppEspacios.s),
      child: ListTile(
        title: Text(p.producto),
        subtitle: Text(
          '${p.unidadesVendidas} vendidas · ventas ${Formato.bs(p.ventas)}'
          '${p.gastoEnCompras > 0 ? ' · compraste ${Formato.bs(p.gastoEnCompras)}' : ''}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Formato.bs(p.ganancia),
                style: textos.titleSmall?.copyWith(color: p.ganancia < 0 ? c.error : c.primary)),
            if (p.margenPct != null) Text('${p.margenPct!.toStringAsFixed(0)}% margen', style: textos.labelSmall),
          ],
        ),
      ),
    );
  }
}
