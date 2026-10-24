import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/stock_comparison.dart';
import '../../widgets/dividend_section.dart';

class DividendsTab extends StatelessWidget {
  const DividendsTab({super.key, required this.comparison});

  final StockComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Dividend data comes from the provider and may be incomplete. '
          '"Unavailable" means the data is missing, which is different from '
          'a company paying no dividend.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < comparison.series.length; i++) ...[
          DividendSection(
            stock: comparison.series[i].stock,
            start: comparison.effectiveStart,
            end: comparison.effectiveEnd,
            currencyHint: comparison.series[i].currency,
            accent: AppColors.series(context, i),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
