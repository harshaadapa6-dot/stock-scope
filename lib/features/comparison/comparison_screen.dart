import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../models/stock_comparison.dart';
import '../../providers/stock_providers.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/period_selector.dart';
import 'dividends_tab.dart';
import 'metrics_tab.dart';
import 'performance_tab.dart';
import 'volatility_tab.dart';

/// Results of a comparison: performance chart, metrics, volatility and
/// dividends. Changing the period re-fetches and recalculates.
class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key});

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final request = ref.read(comparisonRequestProvider);
    if (request == null) return;
    final today = dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: today,
      initialDateRange:
          DateTimeRange(start: request.range.start, end: request.range.end),
    );
    if (picked == null || !context.mounted) return;
    final range = DateRangeSelection(
      start: dateOnly(picked.start),
      end: dateOnly(picked.end),
    );
    final problem = range.validate();
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    ref.read(comparisonRequestProvider.notifier).updateRange(range);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(comparisonRequestProvider);
    final async = ref.watch(comparisonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparison'),
        actions: [
          IconButton(
            tooltip: 'Custom date range',
            icon: const Icon(Icons.date_range),
            onPressed: () => _pickCustom(context, ref),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: DemoBadge()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PeriodSelector(
                selected: request?.range.period,
                onSelected: (p) => ref
                    .read(comparisonRequestProvider.notifier)
                    .updateRange(DateRangeSelection.forPeriod(p)),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const LoadingWidget(message: 'Loading price history\u2026'),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(comparisonProvider),
              ),
              data: (comparison) => _ComparisonTabs(comparison: comparison),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTabs extends StatelessWidget {
  const _ComparisonTabs({required this.comparison});

  final StockComparison comparison;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Performance'),
              Tab(text: 'Metrics'),
              Tab(text: 'Volatility'),
              Tab(text: 'Dividends'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                PerformanceTab(comparison: comparison),
                MetricsTab(comparison: comparison),
                VolatilityTab(comparison: comparison),
                DividendsTab(comparison: comparison),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
