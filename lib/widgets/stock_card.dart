import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/formatters.dart';
import '../models/stock.dart';
import '../providers/stock_providers.dart';
import 'app_card.dart';
import 'change_chip.dart';
import 'data_freshness_label.dart';
import 'error_view.dart';

String _initials(Stock stock) {
  final s = stock.displaySymbol;
  return s.length <= 2 ? s : s.substring(0, 2);
}

/// Presentational card for a stock (no data fetching).
class StockCard extends StatelessWidget {
  const StockCard({
    super.key,
    required this.stock,
    this.onTap,
    this.leading,
    this.trailing,
    this.footer,
  });

  final Stock stock;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      stock.displaySymbol,
      if (stock.exchange != null) stock.exchange!,
      if (stock.currency != null) stock.currency!,
    ].join(' \u00B7 ');
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  _initials(stock),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
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
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// A [StockCard] that loads and shows the latest available close and the
/// change versus the previous close, labelled with the observation date.
class QuoteStockCard extends ConsumerWidget {
  const QuoteStockCard({
    super.key,
    required this.stock,
    this.onTap,
    this.leading,
    this.extraTrailing,
  });

  final Stock stock;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? extraTrailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(quoteProvider(stock.symbol));
    final theme = Theme.of(context);

    final Widget priceBlock = quote.when(
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (q) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.price(q.latest, currency: q.currency ?? stock.currency),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          ChangeChip(percent: q.changePercent, dense: true),
        ],
      ),
    );

    final Widget? footer = quote.when(
      loading: () => null,
      error: (e, _) => ErrorView(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(quoteProvider(stock.symbol)),
      ),
      data: (q) => DataFreshnessLabel(
        asOf: q.asOf,
        sourceName: q.sourceName,
        fromCache: q.fromCache,
        prefix: 'Last close (vs previous close)',
      ),
    );

    return StockCard(
      stock: stock,
      onTap: onTap,
      leading: leading,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          priceBlock,
          if (extraTrailing != null) extraTrailing!,
        ],
      ),
      footer: footer,
    );
  }
}
