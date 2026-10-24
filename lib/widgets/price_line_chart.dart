import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/formatters.dart';
import '../models/historical_price.dart';

/// Single-series closing-price chart with tooltips and first/last markers.
class PriceLineChart extends StatelessWidget {
  const PriceLineChart({
    super.key,
    required this.points,
    required this.color,
    this.currency,
    this.height = 240,
  });

  final List<PricePoint> points;
  final Color color;
  final String? currency;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Not enough data points to draw a chart.'),
        ),
      );
    }
    final base = points.first.date;
    final spots = <FlSpot>[
      for (final p in points)
        FlSpot(daysBetween(base, p.date).toDouble(), p.value),
    ];
    final maxX = math.max(spots.last.x, 1.0);
    var minY = spots.map((s) => s.y).reduce(math.min);
    var maxY = spots.map((s) => s.y).reduce(math.max);
    final pad = math.max((maxY - minY) * 0.08, 0.5);
    minY -= pad;
    maxY += pad;
    final xInterval = math.max(1.0, (maxX / 4).roundToDouble());
    final longSpan = maxX > 400;

    return Semantics(
      label: 'Closing price chart from ${Fmt.date(points.first.date)} to '
          '${Fmt.date(points.last.date)}',
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.alpha(scheme.outline, 0.25),
                strokeWidth: 0.6,
              ),
            ),
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
                      Fmt.compact(value),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant),
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
                            fontSize: 10, color: scheme.onSurfaceVariant),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: color,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, barData) =>
                      spot.x == barData.spots.first.x ||
                      spot.x == barData.spots.last.x,
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.alpha(color, 0.12),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => scheme.surfaceContainerHighest,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touched) {
                  return [
                    for (final spot in touched)
                      LineTooltipItem(
                        '${Fmt.date(DateTime(base.year, base.month, base.day + spot.x.round()))}\n'
                        '${Fmt.price(spot.y, currency: currency)}',
                        TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                  ];
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
