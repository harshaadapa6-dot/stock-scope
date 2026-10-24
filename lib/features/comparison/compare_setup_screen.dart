import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../providers/stock_providers.dart';
import '../../providers/watchlist_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stock_card.dart';
import '../stock_search/stock_search_screen.dart';
import 'comparison_screen.dart';

/// Choose 2-5 stocks and a date range, then run the comparison.
class CompareSetupScreen extends ConsumerWidget {
  const CompareSetupScreen({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final range = ref.read(comparisonRangeProvider);
    final today = dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: range.start,
        end: range.end.isAfter(today) ? today : range.end,
      ),
      helpText: 'Select comparison period',
    );
    if (picked != null) {
      ref
          .read(comparisonRangeProvider.notifier)
          .setCustom(picked.start, picked.end);
    }
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const StockSearchScreen(pickMode: true),
      ),
    );
  }

  void _showWatchlistPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WatchlistPickerSheet(),
    );
  }

  void _compare(BuildContext context, WidgetRef ref) {
    final stocks = ref.read(selectedStocksProvider);
    final range = ref.read(comparisonRangeProvider);
    ref.read(comparisonRequestProvider.notifier).commit(stocks, range);
    ref.read(recentComparisonsProvider.notifier).add(stocks);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ComparisonScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(selectedStocksProvider);
    final range = ref.watch(comparisonRangeProvider);
    final watchlist = ref.watch(watchlistProvider);
    final repo = ref.watch(stockRepositoryProvider);

    final rangeError = range.validate();
    final enoughStocks = selected.length >= AppConstants.minCompareStocks;
    final atLimit = selected.length >= AppConstants.maxCompareStocks;
    final canCompare = enoughStocks && rangeError == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Stocks'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: DemoBadge()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Text(
                '${selected.length} of ${AppConstants.maxCompareStocks} selected',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      ref.read(selectedStocksProvider.notifier).clear(),
                  child: const Text('Clear'),
                ),
            ],
          ),
          Text(
            'Choose ${AppConstants.minCompareStocks} to '
            '${AppConstants.maxCompareStocks} stocks.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (selected.isEmpty)
            const SizedBox(
              height: 160,
              child: EmptyState(
                icon: Icons.add_chart,
                title: 'No stocks selected',
                message: 'Search for stocks or pick from your watchlist.',
              ),
            )
          else
            for (final stock in selected) ...[
              StockCard(
                stock: stock,
                trailing: IconButton(
                  tooltip: 'Remove ${stock.companyName}',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      ref.read(selectedStocksProvider.notifier).remove(stock),
                ),
              ),
              const SizedBox(height: 8),
            ],
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: atLimit ? null : () => _openSearch(context),
                icon: const Icon(Icons.search),
                label: const Text('Add stock'),
              ),
              OutlinedButton.icon(
                onPressed: (atLimit || watchlist.isEmpty)
                    ? null
                    : () => _showWatchlistPicker(context),
                icon: const Icon(Icons.star_outline),
                label: const Text('From watchlist'),
              ),
            ],
          ),
          if (atLimit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Maximum of ${AppConstants.maxCompareStocks} stocks reached.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SectionHeader(title: 'Date range'),
          PeriodSelector(
            selected: range.period,
            onSelected: (p) =>
                ref.read(comparisonRangeProvider.notifier).setPeriod(p),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickCustomRange(context, ref),
            icon: const Icon(Icons.date_range),
            label: Text(range.isCustom ? 'Custom range' : 'Pick custom range'),
          ),
          const SizedBox(height: 8),
          Text(
            '${Fmt.date(range.start)}  \u2192  ${Fmt.date(range.end)}'
            '${range.isCustom ? '  (custom)' : ''}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (rangeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rangeError,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(repo.historyNote,
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: canCompare ? () => _compare(context, ref) : null,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Compare Now'),
            ),
          ),
          if (!enoughStocks)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Select at least ${AppConstants.minCompareStocks} stocks to '
                'enable comparison.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _WatchlistPickerSheet extends ConsumerWidget {
  const _WatchlistPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final selected = ref.watch(selectedStocksProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final stock in watchlist)
              CheckboxListTile(
                value: selected.any((s) => s.symbol == stock.symbol),
                title: Text(stock.companyName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(stock.displaySymbol),
                onChanged: (checked) {
                  final notifier = ref.read(selectedStocksProvider.notifier);
                  if (checked == true) {
                    final result = notifier.add(stock);
                    if (result == AddResult.limitReached) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You can compare at most 5 stocks.'),
                        ),
                      );
                    }
                  } else {
                    notifier.remove(stock);
                  }
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
