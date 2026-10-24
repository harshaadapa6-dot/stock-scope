import '../core/errors/app_exception.dart';
import '../core/utils/date_utils.dart';
import '../models/price_series.dart';
import '../models/stock.dart';
import '../models/stock_comparison.dart';
import 'stock_calculation_service.dart';
import '../models/historical_price.dart';

/// Turns raw per-stock price series into an aligned [StockComparison].
///
/// Alignment strategy (no index-based pairing):
///  1. Each series is cleaned and clipped to the requested range.
///  2. The common start is the latest first-observation date among all
///     usable series, so every stock has a price on or after it.
///  3. Each series is restricted to dates >= common start and normalized to
///     100 at *its own* first observation in that window.
///  4. Charts plot each point at its real calendar date, so stocks with
///     different trading calendars are never matched by array position.
class ComparisonBuilder {
  const ComparisonBuilder({
    StockCalculationService calculator = const StockCalculationService(),
  }) : _calc = calculator;

  final StockCalculationService _calc;

  StockComparison build({
    required List<Stock> stocks,
    required Map<String, PriceSeries> series,
    required DateRangeSelection range,
    Map<String, String> failures = const {},
  }) {
    final failureMap = Map<String, String>.from(failures);
    final usable = <Stock, ({PriceSeries source, List<PricePoint> window})>{};

    for (final stock in stocks) {
      final source = series[stock.symbol];
      if (source == null) continue;
      final cleaned = _calc.cleanSeries(
        source.prices,
        useAdjusted: source.useAdjusted,
      );
      final window = _calc.sliceRange(cleaned, range.start, range.end);
      if (window.length < 2) {
        failureMap[stock.symbol] = window.isEmpty
            ? 'No price data in the selected date range.'
            : 'Only one price observation in the selected date range.';
        continue;
      }
      usable[stock] = (source: source, window: window);
    }

    if (usable.length < 2) {
      throw const AppException(
        AppErrorType.noData,
        'Fewer than two stocks have usable price data for this range.',
        hint: 'Try a longer date range or different stocks.',
      );
    }

    // Common start = latest first date.
    var commonStart = usable.values.first.window.first.date;
    for (final u in usable.values) {
      if (u.window.first.date.isAfter(commonStart)) {
        commonStart = u.window.first.date;
      }
    }

    final comparisonSeries = <ComparisonSeries>[];
    final metrics = <String, StockMetrics>{};
    var effectiveEnd = commonStart;

    for (final entry in usable.entries) {
      final aligned = [
        for (final p in entry.value.window)
          if (!p.date.isBefore(commonStart)) p,
      ];
      if (aligned.length < 2) {
        failureMap[entry.key.symbol] =
            'Too few observations after aligning to the common start date.';
        continue;
      }
      final normalized = _calc.normalize(aligned);
      final points = <ComparisonPoint>[
        for (var i = 0; i < aligned.length; i++)
          ComparisonPoint(
            date: aligned[i].date,
            close: aligned[i].value,
            normalized: normalized[i].value,
          ),
      ];
      final source = entry.value.source;
      comparisonSeries.add(ComparisonSeries(
        stock: entry.key,
        points: points,
        basis: source.basis,
        currency: source.currency ?? entry.key.currency,
        sourceName: source.sourceName,
        fetchedAt: source.fetchedAt,
        fromCache: source.fromCache,
        isDemo: source.isDemo,
      ));
      final m = _calc.computeMetrics(entry.key.symbol, aligned);
      if (m != null) metrics[entry.key.symbol] = m;
      if (aligned.last.date.isAfter(effectiveEnd)) {
        effectiveEnd = aligned.last.date;
      }
    }

    if (comparisonSeries.length < 2) {
      throw const AppException(
        AppErrorType.noData,
        'Fewer than two stocks have overlapping price data for this range.',
        hint: 'Try a longer date range or different stocks.',
      );
    }

    final bases = {for (final s in comparisonSeries) s.basis};
    return StockComparison(
      range: range,
      effectiveStart: commonStart,
      effectiveEnd: effectiveEnd,
      series: comparisonSeries,
      metrics: metrics,
      failures: failureMap,
      mixedBasis: bases.length > 1,
    );
  }
}
