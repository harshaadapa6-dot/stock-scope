import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/stock_comparison.dart';
import '../../providers/stock_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/change_chip.dart';
import '../../widgets/chart_legend.dart';
import '../../widgets/comparison_chart.dart';
import '../../widgets/data_freshness_label.dart';
import '../../widgets/section_header.dart';

class PerformanceTab extends ConsumerWidget {
  const PerformanceTab({super.key, required this.comparison});

  final StockComparison comparison;

  String _modeCaption(ChartMode mode) {
    switch (mode) {
      case ChartMode.normalized:
        return 'Each stock is rescaled so its first price in the shared '
            'period equals 100: normalized = price / starting price \u00D7 100. '
            'A line at 110 means +10% since the start.';
      case ChartMode.percentReturn:
        return 'Percentage change since the shared start date '
            '(normalized \u2212 100).';
      case ChartMode.price:
        return 'Raw closing prices in each stock\u2019s own currency. Only '
            'comparable when all stocks share one currency.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stored = ref.watch(chartModeProvider);
    final mode = (stored == ChartMode.price && !comparison.canCompareRawPrices)
        ? ChartMode.normalized
        : stored;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (comparison.failures.isNotEmpty)
          _Banner(
            icon: Icons.warning_amber_outlined,
            text: 'Some stocks were left out: ' +
                comparison.failures.entries
                    .map((e) => '${e.key.split(':').first} (${e.value})')
                    .join('; '),
          ),
        if (comparison.mixedBasis)
          const _Banner(
            icon: Icons.warning_amber_outlined,
            text: 'These series use different price bases (adjusted vs '
                'unadjusted). Comparing them can be misleading.',
          ),
        if (comparison.startWasShifted)
          _Banner(
            icon: Icons.info_outline,
            text: 'Not every stock has data from the requested start date. '
                'All lines start together on ${Fmt.date(comparison.effectiveStart)}, '
                'the first date shared by all stocks.',
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<ChartMode>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                    value: ChartMode.normalized,
                    label: Text('Normalized'),
                  ),
                  const ButtonSegment(
                    value: ChartMode.percentReturn,
                    label: Text('% return'),
                  ),
                  ButtonSegment(
                    value: ChartMode.price,
                    label: const Text('Price'),
                    enabled: comparison.canCompareRawPrices,
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) =>
                    ref.read(chartModeProvider.notifier).set(s.first),
              ),
              const SizedBox(height: 12),
              Text(mode.axisLabel, style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              ComparisonChart(comparison: comparison, mode: mode),
              const SizedBox(height: 12),
              ChartLegend(items: [
                for (var i = 0; i < comparison.series.length; i++)
                  LegendItem(
                    AppColors.series(context, i),
                    comparison.series[i].stock.displaySymbol,
                  ),
              ]),
              const SizedBox(height: 10),
              Text(
                _modeCaption(mode),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (!comparison.canCompareRawPrices)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Raw price view is disabled because the stocks are not all '
                    'in the same known currency.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Price basis: ${comparison.basis.label}.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Summary'),
        for (var i = 0; i < comparison.series.length; i++) ...[
          _SummaryCard(
            series: comparison.series[i],
            metrics: comparison.metrics[comparison.series[i].stock.symbol],
            color: AppColors.series(context, i),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.series,
    required this.metrics,
    required this.color,
  });

  final ComparisonSeries series;
  final StockMetrics? metrics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = metrics;
    final stock = series.stock;
    final currency = series.currency;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      [
                        stock.displaySymbol,
                        if (stock.exchange != null) stock.exchange!,
                        if (currency != null) currency,
                      ].join(' \u00B7 '),
                      style: muted,
                    ),
                  ],
                ),
              ),
              ChangeChip(percent: m?.percentReturn),
            ],
          ),
          const SizedBox(height: 12),
          if (m == null)
            Text('No metrics available.', style: muted)
          else ...[
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _Stat(
                  label: 'Latest available price',
                  value: Fmt.price(m.endPrice, currency: currency),
                ),
                _Stat(
                  label: 'Change over period',
                  value: Fmt.priceChange(m.absoluteChange, currency: currency),
                  color: AppColors.forValue(context, m.absoluteChange),
                ),
                _Stat(
                  label: 'Return over period',
                  value: Fmt.percent(m.percentReturn),
                  color: AppColors.forValue(context, m.percentReturn),
                ),
                _Stat(
                  label: 'Annualized volatility (historical)',
                  value: Fmt.fractionAsPercent(m.annualizedVolatility),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DataFreshnessLabel(
              asOf: m.lastDate,
              sourceName: series.sourceName,
              fromCache: series.fromCache,
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
