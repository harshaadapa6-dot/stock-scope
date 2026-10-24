import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_scope/models/dividend_info.dart';
import 'package:stock_scope/models/historical_price.dart';
import 'package:stock_scope/services/stock_calculation_service.dart';

HistoricalPrice hp(int day, double close, {double? adj}) => HistoricalPrice(
      date: DateTime(2025, 1, day),
      close: close,
      adjustedClose: adj,
    );

List<PricePoint> pts(List<double> values) => [
      for (var i = 0; i < values.length; i++)
        PricePoint(DateTime(2025, 1, i + 1), values[i]),
    ];

void main() {
  const calc = StockCalculationService();

  group('absolute change / percentage return', () {
    test('basic values', () {
      expect(calc.absoluteChange(100, 110), 10);
      expect(calc.percentageReturn(100, 110), closeTo(10, 1e-9));
      expect(calc.percentageReturn(500, 450), closeTo(-10, 1e-9));
    });
    test('invalid starting prices return null', () {
      expect(calc.percentageReturn(0, 10), isNull);
      expect(calc.percentageReturn(-5, 10), isNull);
      expect(calc.percentageReturn(double.nan, 10), isNull);
      expect(calc.percentageReturn(100, double.infinity), isNull);
      expect(calc.absoluteChange(0, 10), isNull);
    });
  });

  group('cleanSeries', () {
    test('sorts chronologically without mutating input', () {
      final input = [hp(3, 30), hp(1, 10), hp(2, 20)];
      final out = calc.cleanSeries(input);
      expect(out.map((p) => p.value), [10, 20, 30]);
      expect(input.first.close, 30); // untouched
    });
    test('drops NaN, infinite, zero and negative closes', () {
      final out = calc.cleanSeries([
        hp(1, 10),
        hp(2, double.nan),
        hp(3, double.infinity),
        hp(4, 0),
        hp(5, -3),
        hp(6, 12),
      ]);
      expect(out.map((p) => p.value), [10, 12]);
    });
    test('de-duplicates by day, last record wins', () {
      final out = calc.cleanSeries([hp(1, 10), hp(1, 11)]);
      expect(out.length, 1);
      expect(out.first.value, 11);
    });
    test('adjusted mode never falls back to raw close', () {
      final out = calc.cleanSeries(
        [hp(1, 10, adj: 9), hp(2, 11), hp(3, 12, adj: 10)],
        useAdjusted: true,
      );
      expect(out.map((p) => p.value), [9, 10]);
    });
    test('empty input', () {
      expect(calc.cleanSeries(const []), isEmpty);
    });
  });

  group('normalize', () {
    test('first value is 100 and scales proportionally', () {
      final n = calc.normalize(pts([100, 110, 90]));
      expect(n[0].value, 100);
      expect(n[1].value, closeTo(110, 1e-9));
      expect(n[2].value, closeTo(90, 1e-9));
      final b = calc.normalize(pts([500, 450]));
      expect(b.last.value, closeTo(90, 1e-9));
    });
    test('empty and invalid start give empty', () {
      expect(calc.normalize(const []), isEmpty);
      expect(calc.normalize(pts([0, 5])), isEmpty);
    });
  });

  group('daily returns', () {
    test('simple returns', () {
      final r = calc.dailyReturns(pts([100, 110, 99]));
      expect(r[0], closeTo(0.10, 1e-12));
      expect(r[1], closeTo(-0.10, 1e-12));
    });
    test('single or no observation gives no returns', () {
      expect(calc.dailyReturns(pts([100])), isEmpty);
      expect(calc.dailyReturns(const []), isEmpty);
    });
    test('skips pairs with invalid prices', () {
      final r = calc.dailyReturns([
        PricePoint(DateTime(2025, 1, 1), 100),
        PricePoint(DateTime(2025, 1, 2), double.nan),
        PricePoint(DateTime(2025, 1, 3), 110),
      ]);
      expect(r, isEmpty);
    });
  });

  group('standard deviation and volatility', () {
    test('sample (n-1) standard deviation', () {
      // values 2,4,4,4,5,5,7,9: sample sd = sqrt(32/7)
      final sd = calc.sampleStdDev([2, 4, 4, 4, 5, 5, 7, 9]);
      expect(sd, closeTo(math.sqrt(32 / 7), 1e-12));
    });
    test('fewer than two values gives null', () {
      expect(calc.sampleStdDev(const []), isNull);
      expect(calc.sampleStdDev([0.01]), isNull);
      expect(calc.sampleStdDev([double.nan, 0.01]), isNull);
    });
    test('zero variance gives zero', () {
      expect(calc.sampleStdDev([0.01, 0.01, 0.01])!, closeTo(0, 1e-12));
    });
    test('annualized = daily sd * sqrt(252)', () {
      final returns = [0.01, -0.01, 0.02, -0.02];
      final sd = calc.sampleStdDev(returns)!;
      expect(calc.annualizedVolatility(returns), closeTo(sd * math.sqrt(252), 1e-12));
    });
    test('insufficient observations gives null', () {
      expect(calc.annualizedVolatility([0.01]), isNull);
    });
  });

  group('highest / lowest / averages', () {
    test('highest and lowest', () {
      final p = pts([10, 30, 20]);
      expect(calc.highest(p)!.value, 30);
      expect(calc.lowest(p)!.value, 10);
      expect(calc.highest(const []), isNull);
    });
    test('average daily return is arithmetic mean', () {
      expect(calc.averageDailyReturn([0.1, -0.1, 0.3]), closeTo(0.1, 1e-12));
      expect(calc.averageDailyReturn(const []), isNull);
    });
    test('cumulative return needs two observations', () {
      expect(calc.cumulativeReturn(pts([100])), isNull);
      expect(calc.cumulativeReturn(pts([100, 125])), closeTo(25, 1e-9));
    });
  });

  group('computeMetrics', () {
    test('empty gives null', () {
      expect(calc.computeMetrics('X', const []), isNull);
    });
    test('single observation leaves derived values null, not zero', () {
      final m = calc.computeMetrics('X', pts([100]))!;
      expect(m.percentReturn, isNull);
      expect(m.annualizedVolatility, isNull);
      expect(m.observations, 1);
    });
    test('full metrics', () {
      final m = calc.computeMetrics('X', pts([100, 110, 99, 120]))!;
      expect(m.startPrice, 100);
      expect(m.endPrice, 120);
      expect(m.percentReturn, closeTo(20, 1e-9));
      expect(m.absoluteChange, 20);
      expect(m.highest!.value, 120);
      expect(m.lowest!.value, 99);
      expect(m.returnCount, 3);
      expect(m.annualizedVolatility, isNotNull);
    });
  });

  group('sliceRange', () {
    test('inclusive by calendar day', () {
      final out = calc.sliceRange(
        pts([1, 2, 3, 4, 5]),
        DateTime(2025, 1, 2),
        DateTime(2025, 1, 4),
      );
      expect(out.map((p) => p.value), [2, 3, 4]);
    });
  });

  group('dividends', () {
    final start = DateTime(2025, 1, 1);
    final end = DateTime(2025, 12, 31);
    DividendResult result(List<DividendInfo> events, {bool available = true}) =>
        DividendResult(
          available: available,
          events: events,
          sourceName: 'test',
          observedAt: DateTime(2025, 6, 1),
        );

    test('unavailable data is null, not zero', () {
      expect(calc.dividendSummary(result(const [], available: false), start, end),
          isNull);
    });
    test('available but empty is a genuine zero with a note', () {
      final s = calc.dividendSummary(result(const []), start, end)!;
      expect(s.total, 0);
      expect(s.eventCount, 0);
      expect(s.note, isNotNull);
    });
    test('sums events in range only', () {
      final s = calc.dividendSummary(
        result([
          DividendInfo(amount: 2, exDividendDate: DateTime(2025, 3, 1), currency: 'INR'),
          DividendInfo(amount: 3, exDividendDate: DateTime(2025, 9, 1), currency: 'INR'),
          DividendInfo(amount: 9, exDividendDate: DateTime(2024, 9, 1), currency: 'INR'),
        ]),
        start,
        end,
      )!;
      expect(s.total, 5);
      expect(s.eventCount, 2);
      expect(s.currency, 'INR');
    });
    test('withholds total when an event has no ex-date', () {
      final s = calc.dividendSummary(
        result([const DividendInfo(amount: 2)]),
        start,
        end,
      )!;
      expect(s.total, isNull);
      expect(s.note, isNotNull);
    });
    test('withholds total for mixed currencies', () {
      final s = calc.dividendSummary(
        result([
          DividendInfo(amount: 2, exDividendDate: DateTime(2025, 3, 1), currency: 'INR'),
          DividendInfo(amount: 3, exDividendDate: DateTime(2025, 4, 1), currency: 'USD'),
        ]),
        start,
        end,
      )!;
      expect(s.total, isNull);
    });
  });
}
