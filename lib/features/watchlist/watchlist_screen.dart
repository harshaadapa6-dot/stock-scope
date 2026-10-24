import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/stock.dart';
import '../../providers/stock_providers.dart';
import '../../providers/watchlist_provider.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stock_card.dart';
import '../stock_details/stock_details_screen.dart';
import '../stock_search/stock_search_screen.dart';

/// Saved stocks (persisted locally). Items that fail to load stay listed
/// with an error message.
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final Set<String> _checked = {};

  Future<void> _confirmRemove(Stock stock) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from watchlist?'),
        content: Text('${stock.companyName} will be removed from your watchlist.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _checked.remove(stock.symbol);
      await ref.read(watchlistProvider.notifier).remove(stock.symbol);
    }
  }

  void _compareChecked(List<Stock> watchlist) {
    final chosen = [
      for (final s in watchlist)
        if (_checked.contains(s.symbol)) s,
    ];
    ref.read(selectedStocksProvider.notifier).setAll(chosen);
    ref.read(navIndexProvider.notifier).go(1);
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = ref.watch(watchlistProvider);
    final theme = Theme.of(context);
    final count = _checked.length;
    final canCompare =
        count >= AppConstants.minCompareStocks &&
        count <= AppConstants.maxCompareStocks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: DemoBadge()),
          ),
        ],
      ),
      body: watchlist.isEmpty
          ? EmptyState(
              icon: Icons.star_outline,
              title: 'Your watchlist is empty',
              message: 'Save stocks to track their latest available prices.',
              action: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StockSearchScreen(),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Find stocks'),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      Text(
                        'Prices are the latest available closes with their '
                        'dates, not live quotes. Tick 2\u20135 stocks to compare.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      for (final stock in watchlist) ...[
                        QuoteStockCard(
                          stock: stock,
                          leading: Checkbox(
                            value: _checked.contains(stock.symbol),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _checked.add(stock.symbol);
                              } else {
                                _checked.remove(stock.symbol);
                              }
                            }),
                          ),
                          extraTrailing: IconButton(
                            tooltip: 'Remove ${stock.companyName}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmRemove(stock),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StockDetailsScreen(stock: stock),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed:
                            canCompare ? () => _compareChecked(watchlist) : null,
                        icon: const Icon(Icons.compare_arrows),
                        label: Text('Compare selected ($count)'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
