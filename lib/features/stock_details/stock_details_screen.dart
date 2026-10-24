import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../models/stock.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stock_providers.dart';
import '../../providers/watchlist_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/change_chip.dart';
import '../../widgets/data_freshness_label.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/dividend_section.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/price_line_chart.dart';
import '../../widgets/section_header.dart';

/// Stock details and historical price analysis for one stock.
class StockDetailsScreen extends ConsumerStatefulWidget {
  const StockDetailsScreen({super.key, required this.stock});

  final Stock stock;

  @override
  ConsumerState<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends ConsumerState<StockDetailsScreen> {
  late ComparisonPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = ref.read(settingsProvider).defaultPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enriched = ref.watch(stockDetailsProvider(widget.stock.symbol));
    final stock = enriched.valueOrNull ?? widget.stock;
    final inWatchlist = ref
        .watch(watchlistProvider)
        .any((s) => s.symbol == widget.stock.symbol);

    final end = dateOnly(DateTime.now());
    final start = _period.startFor(end);
    final query = PriceQuery(widget.stock.symbol, start, end);
    final analysis = ref.watch(stockAnalysisProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Text(stock.displaySymbol),
        actions: [
          const Center(child: DemoBadge()),
          IconButton(
            tooltip: inWatchlist ? 'Remove from watchlist' : 'Add to watchlist',
            icon: Icon(inWatchlist ? Icons.star : Icons.star_border),
            onPressed: () =>
                ref.read(watchlistProvider.notifier).toggle(widget.stock),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            stock.companyName,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            [
              stock.displaySymbol,
              if (stock.exchange != null) stock.exchange!,
              if (stock.currency != null) stock.currency!,
            ].join(' \u00B7 '),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (stock.description != null) ...[
            const SizedBox(height: 4),
            Text(stock.description!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          PeriodSelector(
            selected: _period,
            onSelected: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 12),
          analysis.when(
            loading: () => const SizedBox(
              height: 280,
              child: LoadingWidget(message: 'Loading price history\u2026'),
            ),
            error: (e, _) => SizedBox(
              height: 320,
              child: ErrorView(
                error: e,
                onRetry: () => ref.invalidate(stockAnalysisProvider(query)),
              ),
            ),
            data: (data) {
              final m = data.metrics;
              if (m == null) {
                return Column(
                  children: [
                    const SizedBox(
                      height: 240,
                      child: EmptyState(
                        icon: Icons.show_chart,
                        title: 'No price data in this range',
                        message: 'Try a longer period.',
                      ),
                    ),
                    Text(ref.watch(stockRepositoryProvider).historyNote,
                        style: theme.textTheme.bodySmall),
                  ],
                );
              }
              final currency = data.series.currency ?? stock.currency;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Latest available price',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          children: [
                            Text(
                              Fmt.price(m.endPrice, currency: currency),
                              style: theme.textTheme.headlineMedium,
                            ),
                            ChangeChip(percent: m.percentReturn),
                            Text('over ${_period.label}',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DataFreshnessLabel(
                          asOf: m.lastDate,
                          sourceName: data.series.sourceName,
                          fromCache: data.series.fromCache,
                        ),
                        const SizedBox(height: 12),
                        PriceLineChart(
                          points: data.points,
                          color: AppColors.series(context, 0),
                          currency: currency,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'First: ${Fmt.date(m.firstDate)} at '
                          '${Fmt.price(m.startPrice, currency: currency)}\n'
                          'Last: ${Fmt.date(m.lastDate)} at '
                          '${Fmt.price(m.endPrice, currency: currency)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Price basis: ${data.series.basis.label}.'
                          '${data.series.useAdjusted ? '' : ' Returns shown here do not include dividends.'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader(title: 'Period statistics'),
                  LayoutBuilder(
                    builder: (context, box) {
                      final w = (box.maxWidth - 12) / 2;
                      final cards = <Widget>[
                        MetricCard(
                          label: 'Return',
                          value: Fmt.percent(m.percentReturn),
                          valueColor:
                              AppColors.forValue(context, m.percentReturn),
                          caption: Fmt.priceChange(m.absoluteChange,
                              currency: currency),
                        ),
                        MetricCard(
                          label: 'Volatility (annualized)',
                          value: Fmt.fractionAsPercent(m.annualizedVolatility),
                          caption: 'Historical, not a forecast',
                        ),
                        MetricCard(
                          label: 'Highest close',
                          value: Fmt.price(m.highest?.value, currency: currency),
                          caption: m.highest == null
                              ? null
                              : Fmt.date(m.highest!.date),
                        ),
                        MetricCard(
                          label: 'Lowest close',
                          value: Fmt.price(m.lowest?.value, currency: currency),
                          caption:
                              m.lowest == null ? null : Fmt.date(m.lowest!.date),
                        ),
                        MetricCard(
                          label: 'Avg daily return',
                          value: Fmt.fractionAsPercent(m.averageDailyReturn,
                              digits: 3, signed: true),
                          caption: 'Arithmetic mean',
                        ),
                        MetricCard(
                          label: 'Observations',
                          value: '${m.observations}',
                          caption: 'Daily closes used',
                        ),
                      ];
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final c in cards) SizedBox(width: w, child: c),
                        ],
                      );
                    },
                  ),
                  const SectionHeader(title: 'Dividends'),
                  DividendSection(
                    stock: stock,
                    start: start,
                    end: end,
                    currencyHint: currency,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () {
              final result = ref
                  .read(selectedStocksProvider.notifier)
                  .add(widget.stock);
              final message = switch (result) {
                AddResult.added => '${stock.displaySymbol} added to comparison.',
                AddResult.duplicate => '${stock.displaySymbol} is already selected.',
                AddResult.limitReached => 'You can compare at most 5 stocks.',
              };
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            },
            icon: const Icon(Icons.add_chart),
            label: const Text('Add to comparison'),
          ),
        ],
      ),
    );
  }
}
