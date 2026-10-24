import 'dart:math' as math;

import '../core/constants/app_constants.dart';
import '../models/dividend_info.dart';
import '../models/historical_price.dart';
import '../models/stock_comparison.dart';

/// Pure, side-effect-free financial calculations.
///
/// Conventions
///  * Prices must be finite and strictly positive to be used.
///  * Series are sorted chronologically and de-duplicated by calendar day
///    (the last record for a day wins). Inputs are never mutated.
///  * Returns are *simple* returns: r(t) = P(t) / P(t-1) - 1.
///  * Functions return null (never 0 or NaN) when a value cannot be computed.
class StockCalculationService {
  const StockCalculationService();

  /// Validates, de-duplicates and sorts raw observations.
  ///
  /// If [useAdjusted] is true only observations that carry a valid
  /// adjustedClose are kept (adjusted and raw values are never mixed).
  List<PricePoint> cleanSeries(
    List<HistoricalPrice> prices, {
    bool useAdjusted = false,
  }) {
    final byDay = <DateTime, double>{};
    for (final p in prices) {
      final value = useAdjusted ? p.adjustedClose : p.close;
      if (value == null || !value.isFinite || value <= 0) continue;
      byDay[DateTime(p.date.year, p.date.month, p.date.day)] = value;
    }
    final points = [
      for (final e in byDay.entries) PricePoint(e.key, e.value),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  /// Observations with start <= date <= end (inclusive, by calendar day).
  List<PricePoint> sliceRange(
    List<PricePoint> points,
    DateTime start,
    DateTime end,
  ) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return [
      for (final p in points)
        if (!p.date.isBefore(s) && !p.date.isAfter(e)) p,
    ];
  }

  bool _validPrice(double v) => v.isFinite && v > 0;

  /// absoluteChange = endingPrice - startingPrice
  double? absoluteChange(double startPrice, double endPrice) {
    if (!_validPrice(startPrice) || !endPrice.isFinite) return null;
    return endPrice - startPrice;
  }

  /// percentageReturn = (end - start) / start * 100   (percentage points)
  double? percentageReturn(double startPrice, double endPrice) {
    if (!_validPrice(startPrice) || !endPrice.isFinite) return null;
    return (endPrice - startPrice) / startPrice * 100;
  }

  /// normalized(t) = P(t) / P(first) * 100. First valid observation == 100.
  List<PricePoint> normalize(List<PricePoint> points, {double base = 100}) {
    if (points.isEmpty) return const [];
    final first = points.first.value;
    if (!_validPrice(first)) return const [];
    return [
      for (final p in points) PricePoint(p.date, p.value / first * base),
    ];
  }

  /// dailyReturn(t) = P(t) / P(t-1) - 1, for consecutive valid observations.
  List<double> dailyReturns(List<PricePoint> points) {
    final returns = <double>[];
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1].value;
      final cur = points[i].value;
      if (!_validPrice(prev) || !_validPrice(cur)) continue;
      final r = cur / prev - 1;
      if (r.isFinite) returns.add(r);
    }
    return returns;
  }

  /// Sample standard deviation (n - 1 denominator). Null if fewer than two
  /// finite values.
  double? sampleStdDev(List<double> values) {
    final v = values.where((x) => x.isFinite).toList();
    if (v.length < 2) return null;
    final mean = v.reduce((a, b) => a + b) / v.length;
    var sumSq = 0.0;
    for (final x in v) {
      sumSq += (x - mean) * (x - mean);
    }
    return math.sqrt(sumSq / (v.length - 1));
  }

  /// annualizedVolatility = dailyStdDev * sqrt(252)   (ratio, not percent).
  /// 252 is the conventional approximate number of trading days per year.
  double? annualizedVolatility(
    List<double> dailyReturns, {
    int tradingDays = AppConstants.tradingDaysPerYear,
  }) {
    final sd = sampleStdDev(dailyReturns);
    if (sd == null) return null;
    return sd * math.sqrt(tradingDays);
  }

  PricePoint? highest(List<PricePoint> points) {
    PricePoint? best;
    for (final p in points) {
      if (!_validPrice(p.value)) continue;
      if (best == null || p.value > best.value) best = p;
    }
    return best;
  }

  PricePoint? lowest(List<PricePoint> points) {
    PricePoint? best;
    for (final p in points) {
      if (!_validPrice(p.value)) continue;
      if (best == null || p.value < best.value) best = p;
    }
    return best;
  }

  /// Arithmetic mean of daily simple returns. NOT the compound (geometric)
  /// growth rate; see [cumulativeReturn] for that.
  double? averageDailyReturn(List<double> dailyReturns) {
    final v = dailyReturns.where((x) => x.isFinite).toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  /// cumulativeReturn = (end / start - 1) * 100 over the series, in
  /// percentage points. With adjusted prices this follows the provider's
  /// adjustment methodology.
  double? cumulativeReturn(List<PricePoint> points) {
    if (points.length < 2) return null;
    return percentageReturn(points.first.value, points.last.value);
  }

  /// Computes all per-stock metrics for an already cleaned, range-limited
  /// series. Returns null for an empty series.
  StockMetrics? computeMetrics(String symbol, List<PricePoint> points) {
    if (points.isEmpty) return null;
    final first = points.first;
    final last = points.last;
    final returns = dailyReturns(points);
    return StockMetrics(
      symbol: symbol,
      observations: points.length,
      firstDate: first.date,
      lastDate: last.date,
      startPrice: first.value,
      endPrice: last.value,
      absoluteChange:
          points.length >= 2 ? absoluteChange(first.value, last.value) : null,
      percentReturn: cumulativeReturn(points),
      dailyVolatility: sampleStdDev(returns),
      annualizedVolatility: annualizedVolatility(returns),
      highest: highest(points),
      lowest: lowest(points),
      averageDailyReturn: averageDailyReturn(returns),
      returnCount: returns.length,
    );
  }

  /// Summarises dividends inside [start]..[end].
  ///
  /// Returns null when the provider could not supply dividend data (missing
  /// data is NOT the same as zero dividends). The total is withheld (null,
  /// with an explanatory note) if any in-scope event lacks an ex-dividend
  /// date or if currencies are mixed.
  DividendSummary? dividendSummary(
    DividendResult result,
    DateTime start,
    DateTime end,
  ) {
    if (!result.available) return null;
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);

    final valid = result.events.where((d) => d.amount.isFinite && d.amount >= 0);
    final undated = valid.where((d) => d.exDividendDate == null).length;
    final inRange = valid.where((d) {
      final ex = d.exDividendDate;
      if (ex == null) return false;
      final day = DateTime(ex.year, ex.month, ex.day);
      return !day.isBefore(s) && !day.isAfter(e);
    }).toList();

    final currencies = {
      for (final d in inRange)
        if (d.currency != null) d.currency!,
    };

    if (undated > 0) {
      return DividendSummary(
        eventCount: inRange.length,
        total: null,
        note: '$undated event(s) have no ex-dividend date, so a total for this '
            'period cannot be determined reliably.',
      );
    }
    if (currencies.length > 1) {
      return DividendSummary(
        eventCount: inRange.length,
        total: null,
        note: 'Events are reported in multiple currencies; no total computed.',
      );
    }
    final total = inRange.fold<double>(0, (sum, d) => sum + d.amount);
    return DividendSummary(
      eventCount: inRange.length,
      total: total,
      currency: currencies.isEmpty ? null : currencies.first,
      note: inRange.isEmpty
          ? 'The provider reports no dividend events in this period.'
          : null,
    );
  }
}
