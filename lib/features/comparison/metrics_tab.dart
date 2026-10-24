import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/stock_comparison.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/section_header.dart';

/// Side-by-side metric cards with plain-language descriptions.
///
/// Badges such as "Highest return" only describe the selected historical
/// period. They are not recommendations.
class MetricsTab extends StatelessWidget {
  const MetricsTab({super.key, required this.comparison});

  final StockComparison comparison;

  String? _badge(List<double?> values, int i,
      {required bool highest, required String text}) {
    final present = values.whereType<double>().toList();
    if (present.length < 2) return null;
    final best = highest ? present.reduce(math.max) : present.reduce(math.min);
    return values[i] == best ? text : null;
  }

  @override
  Widget build(BuildContext context) {
    final series = comparison.series;
    final metrics = [for (final s in series) comparison.metrics[s.stock.symbol]];

    List<MetricEntry> entries(
      String Function(StockMetrics m, ComparisonSeries s) value, {
      Color? Function(StockMetrics m)? color,
      List<double?>? badgeValues,
      bool badgeHighest = true,
      String badgeText = '',
    }) {
      return [
        for (var i = 0; i < series.length; i++)
          MetricEntry(
            label: series[i].stock.displaySymbol,
            seriesColor: AppColors.series(context, i),
            value: metrics[i] == null
                ? Fmt.missing
                : value(metrics[i]!, series[i]),
            valueColor: metrics[i] == null ? null : color?.call(metrics[i]!),
            badge: badgeValues == null
                ? null
                : _badge(badgeValues, i,
                    highest: badgeHighest, text: badgeText),
          ),
      ];
    }

    final returns = [for (final m in metrics) m?.percentReturn];
    final vols = [for (final m in metrics) m?.annualizedVolatility];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        MetricComparisonCard(
          title: 'Latest available price',
          description: 'The most recent closing price in the selected period '
              '(not necessarily today\u2019s price).',
          entries: entries((m, s) => Fmt.price(m.endPrice, currency: s.currency)),
        ),
        const SizedBox(height: 10),
        MetricComparisonCard(
          title: 'Price change over period',
          description: 'Ending price minus starting price, in each stock\u2019s '
              'own currency.',
          entries: entries(
            (m, s) => Fmt.priceChange(m.absoluteChange, currency: s.currency),
            color: (m) => AppColors.forValue(context, m.absoluteChange),
          ),
        ),
        const SizedBox(height: 10),
        MetricComparisonCard(
          title: 'Return over period',
          description: '(Ending price \u2212 starting price) \u00F7 starting '
              'price. A historical result, not a forecast.',
          entries: entries(
            (m, s) => Fmt.percent(m.percentReturn),
            color: (m) => AppColors.forValue(context, m.percentReturn),
            badgeValues: returns,
            badgeText: 'Highest return',
          ),
        ),
        const SizedBox(height: 10),
        MetricComparisonCard(
          title: 'Annualized volatility (historical)',
          description: 'Standard deviation of daily returns \u00D7 \u221A252. '
              'Higher means the price moved around more in this period. It '
              'describes the past, not future risk.',
          entries: entries(
            (m, s) => Fmt.fractionAsPercent(m.annualizedVolatility),
            badgeValues: vols,
            badgeHighest: false,
            badgeText: 'Lowest volatility',
          ),
        ),
        const SizedBox(height: 10),
        MetricComparisonCard(
          title: 'Highest closing price',
          description: 'The maximum closing price in the selected period.',
          entries: entries((m, s) {
            final h = m.highest;
            return h == null
                ? Fmt.missing
                : '${Fmt.price(h.value, currency: s.currency)} '
                    '(${Fmt.dateShort(h.date)})';
          }),
        ),
        const SizedBox(height: 10),
        MetricComparisonCard(
          title: 'Lowest closing price',
          description: 'The minimum closing price in the selected period.',
          entries: entries((m, s) {
            final l = m.lowest;
            return l == null
                ? Fmt.missing
                : '${Fmt.price(l.value, currency: s.currency)} '
                    '(${Fmt.dateShort(l.date)})';
          }),
        ),
        const SizedBox(height: 10),
        MetricComparisonCard(
          title: 'Average daily return',
          description: 'Arithmetic mean of daily percentage changes. This is '
              'not the compound growth rate, so it will not match the '
              'period return.',
          entries: entries(
            (m, s) => Fmt.fractionAsPercent(m.averageDailyReturn,
                digits: 3, signed: true),
            color: (m) => AppColors.forValue(context, m.averageDailyReturn),
          ),
        ),
        const SizedBox(height: 10),
        const MetricComparisonCard(
          title: 'Dividends',
          description: 'Dividend events are loaded separately when available. '
              'Open the Dividends tab to see them, along with whether the '
              'data provider supplies dividend information at all.',
          entries: [],
        ),
        const SectionHeader(title: 'How to read this'),
        Text(
          'Badges such as "Highest return" only describe this historical '
          'period. They do not mean a stock is a better investment: returns '
          'depend on the dates chosen, and volatility and dividends matter too.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Price basis: ${comparison.basis.label}. '
          'Observations used: '
          '${[for (var i = 0; i < series.length; i++) '${series[i].stock.displaySymbol} ${metrics[i]?.observations ?? 0}'].join(', ')}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
