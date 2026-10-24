import 'package:flutter_test/flutter_test.dart';
import 'package:stock_scope/core/errors/app_exception.dart';
import 'package:stock_scope/core/utils/date_utils.dart';
import 'package:stock_scope/models/historical_price.dart';
import 'package:stock_scope/models/price_series.dart';
import 'package:stock_scope/models/stock.dart';
import 'package:stock_scope/services/comparison_builder.dart';

PriceSeries series(String symbol, Map<int, double> byDay) => PriceSeries(
      symbol: symbol,
      prices: [
        for (final e in byDay.entries)
          HistoricalPrice(date: DateTime(2025, 1, e.key), close: e.value),
      ],
      basis: PriceBasis.unadjusted,
      currency: 'INR',
      sourceName: 'test',
      fetchedAt: DateTime(2025, 2, 1),
    );

void main() {
  const builder = ComparisonBuilder();
  const a = Stock(symbol: 'A', companyName: 'A Co');
  const b = Stock(symbol: 'B', companyName: 'B Co');
  final range = DateRangeSelection(
    start: DateTime(2025, 1, 1),
    end: DateTime(2025, 1, 31),
  );

  test('aligns by date to the common start and normalizes to 100', () {
    // B starts later (day 3); A has an extra earlier day.
    final result = builder.build(
      stocks: [a, b],
      range: range,
      series: {
        'A': series('A', {1: 100, 2: 105, 3: 110, 4: 121}),
        'B': series('B', {3: 500, 4: 450, 5: 400}),
      },
    );
    expect(result.effectiveStart, DateTime(2025, 1, 3));
    final sa = result.seriesFor('A')!;
    final sb = result.seriesFor('B')!;
    expect(sa.points.first.date, DateTime(2025, 1, 3));
    expect(sa.points.first.normalized, 100);
    expect(sa.points.last.normalized, closeTo(110, 1e-9)); // 121/110*100
    expect(sb.points.last.normalized, closeTo(80, 1e-9));
    expect(result.metrics['B']!.percentReturn, closeTo(-20, 1e-9));
  });

  test('different calendars are not paired by index', () {
    final result = builder.build(
      stocks: [a, b],
      range: range,
      series: {
        'A': series('A', {1: 100, 2: 101, 4: 103}),
        'B': series('B', {1: 50, 3: 51, 4: 52}),
      },
    );
    final aDates = result.seriesFor('A')!.points.map((p) => p.date.day);
    final bDates = result.seriesFor('B')!.points.map((p) => p.date.day);
    expect(aDates, [1, 2, 4]);
    expect(bDates, [1, 3, 4]);
  });

  test('stock without data in range is reported as a failure', () {
    const c = Stock(symbol: 'C', companyName: 'C Co');
    final result = builder.build(
      stocks: [a, b, c],
      range: range,
      series: {
        'A': series('A', {1: 100, 2: 101}),
        'B': series('B', {1: 50, 2: 51}),
        'C': series('C', {}),
      },
    );
    expect(result.series.length, 2);
    expect(result.failures.containsKey('C'), isTrue);
  });

  test('throws when fewer than two stocks are usable', () {
    expect(
      () => builder.build(
        stocks: [a, b],
        range: range,
        series: {
          'A': series('A', {1: 100, 2: 101}),
          'B': series('B', {}),
        },
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('raw price comparison requires a single shared currency', () {
    final result = builder.build(
      stocks: [a, b],
      range: range,
      series: {
        'A': series('A', {1: 100, 2: 101}),
        'B': series('B', {1: 50, 2: 51}),
      },
    );
    expect(result.canCompareRawPrices, isTrue);
  });
}
