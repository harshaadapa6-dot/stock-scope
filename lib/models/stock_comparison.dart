import '../core/utils/date_utils.dart';
import 'historical_price.dart';
import 'price_series.dart';
import 'stock.dart';

/// One aligned observation in a comparison series.
class ComparisonPoint {
  const ComparisonPoint({
    required this.date,
    required this.close,
    required this.normalized,
  });

  final DateTime date;

  /// Closing price used for calculations (adjusted or not, per series basis).
  final double close;

  /// close / firstClose * 100 where firstClose is the first observation on or
  /// after the common start date.
  final double normalized;
}

class ComparisonSeries {
  const ComparisonSeries({
    required this.stock,
    required this.points,
    required this.basis,
    required this.sourceName,
    required this.fetchedAt,
    required this.fromCache,
    required this.isDemo,
    this.currency,
  });

  final Stock stock;
  final List<ComparisonPoint> points;
  final PriceBasis basis;
  final String? currency;
  final String sourceName;
  final DateTime fetchedAt;
  final bool fromCache;
  final bool isDemo;

  DateTime get lastDate => points.last.date;
}

/// Per-stock statistics for a window. Nullable where the value cannot be
/// computed (e.g. too few observations).
class StockMetrics {
  const StockMetrics({
    required this.symbol,
    required this.observations,
    required this.firstDate,
    required this.lastDate,
    required this.startPrice,
    required this.endPrice,
    this.absoluteChange,
    this.percentReturn,
    this.dailyVolatility,
    this.annualizedVolatility,
    this.highest,
    this.lowest,
    this.averageDailyReturn,
    this.returnCount = 0,
  });

  final String symbol;
  final int observations;
  final DateTime firstDate;
  final DateTime lastDate;
  final double startPrice;
  final double endPrice;
  final double? absoluteChange;

  /// Percentage points (10.0 means +10%).
  final double? percentReturn;

  /// Sample standard deviation of daily simple returns (a ratio, 0.012 = 1.2%).
  final double? dailyVolatility;

  /// dailyVolatility * sqrt(252), as a ratio.
  final double? annualizedVolatility;
  final PricePoint? highest;
  final PricePoint? lowest;

  /// Arithmetic mean of daily simple returns, as a ratio.
  final double? averageDailyReturn;
  final int returnCount;
}

class StockComparison {
  const StockComparison({
    required this.range,
    required this.effectiveStart,
    required this.effectiveEnd,
    required this.series,
    required this.metrics,
    required this.failures,
    required this.mixedBasis,
  });

  final DateRangeSelection range;

  /// First date shared by all plotted series (all normalize to 100 here).
  final DateTime effectiveStart;
  final DateTime effectiveEnd;
  final List<ComparisonSeries> series;
  final Map<String, StockMetrics> metrics;

  /// symbol -> reason, for stocks that were requested but could not be used.
  final Map<String, String> failures;

  /// True if series use different price bases (should never normally happen).
  final bool mixedBasis;

  List<Stock> get stocks => series.map((s) => s.stock).toList();
  bool get isDemo => series.any((s) => s.isDemo);
  bool get anyCached => series.any((s) => s.fromCache);

  Set<String> get currencies => {
        for (final s in series)
          if (s.currency != null) s.currency!,
      };

  /// Raw price lines are only meaningful when every series is in the same,
  /// known currency and price basis.
  bool get canCompareRawPrices =>
      !mixedBasis &&
      series.every((s) => s.currency != null) &&
      currencies.length == 1;

  /// True when the shared start is noticeably later than requested.
  bool get startWasShifted => daysBetween(range.start, effectiveStart) > 7;

  PriceBasis get basis => series.first.basis;

  ComparisonSeries? seriesFor(String symbol) {
    for (final s in series) {
      if (s.stock.symbol == symbol) return s;
    }
    return null;
  }
}
