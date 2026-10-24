import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/formatters.dart';
import '../models/dividend_info.dart';
import '../models/stock.dart';
import '../providers/stock_providers.dart';
import '../services/stock_calculation_service.dart';
import 'app_card.dart';
import 'demo_badge.dart';
import 'error_view.dart';

/// Dividend information for one stock over a date window.
///
/// Handles the three distinct states: provider cannot supply dividends
/// (missing), provider reports no events (genuine none), and events present.
/// Nothing is invented and missing data is never shown as zero.
class DividendSection extends ConsumerWidget {
  const DividendSection({
    super.key,
    required this.stock,
    required this.start,
    required this.end,
    this.currencyHint,
    this.accent,
  });

  final Stock stock;
  final DateTime start;
  final DateTime end;
  final String? currencyHint;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = PriceQuery(stock.symbol, start, end);
    final async = ref.watch(dividendsProvider(query));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (accent != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  '${stock.companyName} (${stock.displaySymbol})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => ErrorView(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(dividendsProvider(query)),
            ),
            data: (result) => _content(context, result),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, DividendResult result) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final provenance = Text(
      'Source: ${result.sourceName} \u00B7 observed ${Fmt.dateTime(result.observedAt)}',
      style: muted,
    );

    if (!result.available) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text('Dividend data unavailable',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(result.unavailableReason ?? 'No reason given by the provider.',
              style: muted),
          const SizedBox(height: 4),
          Text(
            'This does not mean the company pays no dividends; the data is '
            'simply not available here.',
            style: muted,
          ),
          const SizedBox(height: 8),
          provenance,
        ],
      );
    }

    const calc = StockCalculationService();
    final summary = calc.dividendSummary(result, start, end);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final shown = result.events.where((d) {
      final ex = d.exDividendDate;
      if (ex == null) return true;
      final day = DateTime(ex.year, ex.month, ex.day);
      return !day.isBefore(s) && !day.isAfter(e);
    }).toList()
      ..sort((a, b) {
        final ad = a.exDividendDate;
        final bd = b.exDividendDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    final currency = summary?.currency ?? currencyHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.isSynthetic) ...[
          const DemoBadgeLabel(),
          const SizedBox(height: 4),
          Text('Synthetic sample dividend events, not real payouts.',
              style: muted),
          const SizedBox(height: 8),
        ],
        if (summary?.total != null)
          Text(
            'Reported in this period: ${Fmt.price(summary!.total, currency: currency)}'
            ' \u00B7 ${summary.eventCount} event(s)',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        if (summary?.note != null) Text(summary!.note!, style: muted),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final d in shown.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.exDividendDate == null
                          ? 'Ex-dividend date unavailable'
                          : 'Ex-date ${Fmt.date(d.exDividendDate)}',
                    ),
                  ),
                  Text(
                    Fmt.price(d.amount, currency: d.currency ?? currency),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          if (shown.length > 8)
            Text('+ ${shown.length - 8} more event(s)', style: muted),
        ],
        const SizedBox(height: 8),
        Text(
          'Annual dividend total and dividend yield are not calculated: they '
          'need complete trailing-12-month records and a consistent price '
          'basis, which this app cannot guarantee.',
          style: muted,
        ),
        const SizedBox(height: 8),
        provenance,
      ],
    );
  }
}
