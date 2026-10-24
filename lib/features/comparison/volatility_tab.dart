import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/stock_comparison.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

/// Historical volatility from daily returns.
class VolatilityTab extends StatelessWidget {
  const VolatilityTab({super.key, required this.comparison});

  final StockComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final series = comparison.series;
    final vols = [
      for (final s in series)
        comparison.metrics[s.stock.symbol]?.annualizedVolatility,
    ];
    final maxVol = vols.whereType<double>().fold<double>(0, math.max);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How it is calculated', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                '1. Daily simple return: r(t) = P(t) / P(t\u22121) \u2212 1\n'
                '2. Sample standard deviation of the daily returns\n'
                '3. Annualized = daily deviation \u00D7 \u221A${AppConstants.tradingDaysPerYear}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'The annualization assumes about ${AppConstants.tradingDaysPerYear} '
                'trading days per year, a common convention. Volatility is '
                'historical: it describes how much prices moved in the '
                'selected period and is not a prediction of future risk. '
                'Price basis: ${comparison.basis.shortLabel}.',
                style: muted,
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'By stock'),
        for (var i = 0; i < series.length; i++) ...[
          _VolatilityCard(
            series: series[i],
            metrics: comparison.metrics[series[i].stock.symbol],
            color: AppColors.series(context, i),
            maxVol: maxVol,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _VolatilityCard extends StatelessWidget {
  const _VolatilityCard({
    required this.series,
    required this.metrics,
    required this.color,
    required this.maxVol,
  });

  final ComparisonSeries series;
  final StockMetrics? metrics;
  final Color color;
  final double maxVol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final m = metrics;
    final annual = m?.annualizedVolatility;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${series.stock.companyName} (${series.stock.displaySymbol})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (annual == null)
            Text(
              'Not enough price observations to calculate volatility '
              '(at least 3 prices are needed).',
              style: muted,
            )
          else ...[
            Text(
              Fmt.fractionAsPercent(annual),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('annualized historical volatility', style: muted),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: maxVol <= 0 ? 0 : (annual / maxVol).clamp(0.0, 1.0),
                minHeight: 10,
                color: color,
                backgroundColor: AppColors.alpha(color, 0.18),
              ),
            ),
            const SizedBox(height: 4),
            Text('Bar length is relative to the most volatile stock shown.',
                style: muted),
            const SizedBox(height: 8),
            Text(
              'Daily volatility: ${Fmt.fractionAsPercent(m?.dailyVolatility, digits: 3)}'
              ' \u00B7 ${m?.returnCount ?? 0} daily returns used',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
