import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/formatters.dart';
import '../models/stock_comparison.dart';
import '../providers/stock_providers.dart';

/// Multi-series line chart. Rendering only: all numbers come from the
/// already-computed [StockComparison].
///
/// Every point is positioned by its calendar date (days since the common
/// start), never by array index, so stocks with different trading calendars
/// stay correctly aligned.
class ComparisonChart extends StatelessWidget {
  const ComparisonChart({
    super.key,
    required this.comparison,
    required this.mode,
    this.height = 300,
  });

  final StockComparison comparison;
  final ChartMode mode;
  final double height;

  double _yOf(ComparisonPoint p) {
    switch (mode) {
      case ChartMode.normalized:
        return p.normalized;
      case ChartMode.percentReturn:
        return p.normalized - 100;
      case ChartMode.price:
        return p.close;
    }
  }

  String _axisLabel(double v) {
    switch (mode) {
      case ChartMode.normalized:
        return v.toStringAsFixed(0);
      case ChartMode.percentReturn:
        return '${v > 0 ? '+' : ''}${v.toStringAsFixed(0)}%';
      case ChartMode.price:
        return Fmt.compact(v);
    }
  }

  String _tooltipValue(double v, String? currency) {
    switch (mode) {
      case ChartMode.normalized:
        return v.toStringAsFixed(2);
      case ChartMode.percentReturn:
        return Fmt.percent(v);
      case ChartMode.price:
        return Fmt.price(v, currency: currency);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = comparison.effectiveStart;

    final bars = <LineChartBarData>[];
    var minY = double.infinity;
    var maxY = -double.infinity;
    var maxX = 0.0;

    for (var i = 0; i < comparison.series.length; i++) {
      final s = comparison.series[i];
      final color = AppColors.series(context, i);
      final spots = <FlSpot>[];
      for (final p in s.points) {
        final y = _yOf(p);
        if (!y.isFinite) continue;
        final x = daysBetween(base, p.date).toDouble();
        spots.add(FlSpot(x, y));
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        maxX = math.max(maxX, x);
      }
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    if (!minY.isFinite || !maxY.isFinite) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No chartable data for this mode.')),
      );
    }

    final double? baseline = mode == ChartMode.normalized
        ? 100.0
        : (mode == ChartMode.percentReturn ? 0.0 : null);
    if (baseline != null) {
      minY = math.min(minY, baseline);
      maxY = math.max(maxY, baseline);
    }
    final pad = math.max((maxY - minY) * 0.08, 0.5);
    maxX = math.max(maxX, 1);
    final xInterval = math.max(1.0, (maxX / 4).roundToDouble());
    final longSpan = maxX > 400;

    return Semantics(
      label: '${mode.axisLabel} line chart for '
          '${comparison.series.map((s) => s.stock.displaySymbol).join(', ')} '
          'from ${Fmt.date(comparison.effectiveStart)} to '
          '${Fmt.date(comparison.effectiveEnd)}',
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: minY - pad,
            maxY: maxY + pad,
            lineBarsData: bars,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.alpha(scheme.outline, 0.25),
                strokeWidth: 0.6,
              ),
            ),
            extraLinesData: baseline == null
                ? null
                : ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: baseline,
                      color: AppColors.alpha(scheme.onSurface, 0.45),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                    ),
                  ]),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _axisLabel(value),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) {
                    final d = DateTime(
                        base.year, base.month, base.day + value.round());
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        longSpan ? Fmt.monthYear(d) : Fmt.dateShort(d),
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => scheme.surfaceContainerHighest,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touched) {
                  final items = <LineTooltipItem?>[];
                  final firstX = touched.isEmpty ? 0.0 : touched.first.x;
                  for (var k = 0; k < touched.length; k++) {
                    final spot = touched[k];
                    final series = comparison.series[spot.barIndex];
                    final color = AppColors.series(context, spot.barIndex);
                    final date = DateTime(
                        base.year, base.month, base.day + spot.x.round());
                    final header = k == 0 ? '${Fmt.date(date)}\n' : '';
                    final ownDate = (spot.x != firstX && k > 0)
                        ? ' (${Fmt.dateShort(date)})'
                        : '';
                    items.add(LineTooltipItem(
                      '$header${series.stock.displaySymbol}  '
                      '${_tooltipValue(spot.y, series.currency)}$ownDate',
                      TextStyle(
                        color: k == 0 ? scheme.onSurface : color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ));
                  }
                  return items;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
