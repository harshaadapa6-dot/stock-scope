import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/stock.dart';
import '../../providers/stock_providers.dart';
import '../../providers/watchlist_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stock_card.dart';
import '../stock_details/stock_details_screen.dart';
import '../stock_search/stock_search_screen.dart';

/// Home dashboard: search, compare shortcut, watchlist preview, sample or
/// suggested stocks and recent comparisons.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StockSearchScreen()),
    );
  }

  void _openDetails(BuildContext context, Stock stock) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StockDetailsScreen(stock: stock)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDemo = ref.watch(isDemoProvider);
    final repo = ref.watch(stockRepositoryProvider);
    final watchlist = ref.watch(watchlistProvider);
    final recents = ref.watch(recentComparisonsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.show_chart,
                      color: theme.colorScheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConstants.appName,
                          style: theme.textTheme.titleLarge),
                      Text(
                        AppConstants.tagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const DemoBadge(),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              onTap: () => _openSearch(context),
              decoration: InputDecoration(
                hintText: 'Search company name or ticker',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => ref.read(navIndexProvider.notifier).go(1),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare Stocks'),
              ),
            ),
            if (isDemo) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.science_outlined,
                        color: theme.colorScheme.tertiary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Demo mode: all prices are synthetic samples, not real '
                        'market data and not connected to any exchange.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SectionHeader(
              title: 'Watchlist',
              trailing: TextButton(
                onPressed: () => ref.read(navIndexProvider.notifier).go(2),
                child: const Text('See all'),
              ),
            ),
            if (watchlist.isEmpty)
              Text(
                'Nothing here yet. Open a stock and tap the star to save it.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final stock in watchlist.take(3)) ...[
                QuoteStockCard(
                  stock: stock,
                  onTap: () => _openDetails(context, stock),
                ),
                const SizedBox(height: 8),
              ],
            SectionHeader(
              title: isDemo ? 'Sample stocks (synthetic)' : 'Suggested stocks',
            ),
            if (isDemo)
              for (final stock in repo.suggestedStocks) ...[
                QuoteStockCard(
                  stock: stock,
                  onTap: () => _openDetails(context, stock),
                ),
                const SizedBox(height: 8),
              ]
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final stock in repo.suggestedStocks)
                    ActionChip(
                      label: Text(stock.displaySymbol),
                      tooltip: stock.companyName,
                      onPressed: () => _openDetails(context, stock),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Live quotes are not preloaded on the dashboard, to conserve '
                'your data provider\u2019s request limit. Open a stock to load '
                'its latest available close.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SectionHeader(title: 'Recently compared'),
            if (recents.isEmpty)
              Text(
                'Your last comparisons will appear here.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final group in recents) ...[
                AppCard(
                  onTap: () {
                    ref.read(selectedStocksProvider.notifier).setAll(group);
                    ref.read(navIndexProvider.notifier).go(1);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.history),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          group.map((s) => s.displaySymbol).join('  vs  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 8),
            const DisclaimerNote(text: AppConstants.disclaimer),
          ],
        ),
      ),
    );
  }
}
