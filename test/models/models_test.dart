import 'package:flutter_test/flutter_test.dart';
import 'package:stock_scope/core/utils/date_utils.dart';
import 'package:stock_scope/core/utils/formatters.dart';
import 'package:stock_scope/models/dividend_info.dart';
import 'package:stock_scope/models/historical_price.dart';
import 'package:stock_scope/models/stock.dart';

void main() {
  test('Stock JSON round-trip and equality by symbol', () {
    const s = Stock(
        symbol: 'TCS:NSE', companyName: 'TCS', exchange: 'NSE', currency: 'INR');
    final back = Stock.fromJson(s.toJson());
    expect(back, s);
    expect(back.exchange, 'NSE');
    expect(back.displaySymbol, 'TCS');
    expect(const Stock(symbol: 'ITC', companyName: 'x').displaySymbol, 'ITC');
  });

  test('HistoricalPrice keeps nullable fields null', () {
    final p = HistoricalPrice(date: DateTime(2025, 1, 2), close: 10);
    final back = HistoricalPrice.fromJson(p.toJson());
    expect(back.adjustedClose, isNull);
    expect(back.volume, isNull);
    expect(back.close, 10);
  });

  test('DividendInfo round-trip', () {
    final d = DividendInfo(
        amount: 2.5, exDividendDate: DateTime(2025, 3, 1), currency: 'INR');
    final back = DividendInfo.fromJson(d.toJson());
    expect(back.amount, 2.5);
    expect(back.paymentDate, isNull);
  });

  group('DateRangeSelection', () {
    final today = DateTime(2026, 6, 30);
    test('valid preset', () {
      final r = DateRangeSelection.forPeriod(ComparisonPeriod.oneYear, today: today);
      expect(r.start, DateTime(2025, 6, 30));
      expect(r.validate(today: today), isNull);
    });
    test('rejects reversed, future and too-short ranges', () {
      expect(
          DateRangeSelection(start: DateTime(2026, 5, 1), end: DateTime(2026, 4, 1))
              .validate(today: today),
          isNotNull);
      expect(
          DateRangeSelection(start: DateTime(2026, 5, 1), end: DateTime(2026, 8, 1))
              .validate(today: today),
          isNotNull);
      expect(
          DateRangeSelection(start: DateTime(2026, 6, 28), end: DateTime(2026, 6, 30))
              .validate(today: today),
          isNotNull);
    });
  });

  group('Fmt', () {
    test('missing values render as a dash, never zero', () {
      expect(Fmt.price(null), Fmt.missing);
      expect(Fmt.percent(double.nan), Fmt.missing);
    });
    test('signed percent', () {
      expect(Fmt.percent(10), '+10.00%');
      expect(Fmt.percent(-2.5), '-2.50%');
      expect(Fmt.percent(0), '0.00%');
    });
    test('INR price uses rupee sign and Indian grouping', () {
      expect(Fmt.price(1234567.5, currency: 'INR'), '\u20B912,34,567.50');
    });
  });
}
