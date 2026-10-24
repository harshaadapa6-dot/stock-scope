import 'package:flutter_test/flutter_test.dart';
import 'package:stock_scope/core/errors/app_exception.dart';
import 'package:stock_scope/data/datasources/demo_market_data_source.dart';
import 'package:stock_scope/services/stock_calculation_service.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 30, 12);
  DemoMarketDataSource make() => DemoMarketDataSource(clock: () => fixedNow);

  test('is flagged as demo and offers the five sample symbols', () {
    final s = make();
    expect(s.isDemo, isTrue);
    expect(s.suggestedStocks.map((e) => e.symbol),
        ['RELIANCE', 'TCS', 'INFY', 'HDFCBANK', 'ITC']);
  });

  test('search matches symbol and name, case-insensitively', () async {
    final s = make();
    expect((await s.searchStocks('tcs')).single.symbol, 'TCS');
    expect((await s.searchStocks('infosys')).single.symbol, 'INFY');
    expect(await s.searchStocks('zzzz'), isEmpty);
    expect(await s.searchStocks('  '), isEmpty);
  });

  test('data is reproducible across instances and calls', () async {
    final a = await make().getHistoricalPrices(
      symbol: 'INFY',
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 12, 31),
    );
    final b = await make().getHistoricalPrices(
      symbol: 'INFY',
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 12, 31),
    );
    expect(a.prices.length, b.prices.length);
    expect(a.prices.first.close, b.prices.first.close);
    expect(a.prices.last.close, b.prices.last.close);
    expect(a.isDemo, isTrue);
  });

  test('same date has the same price regardless of requested window', () async {
    final s = make();
    final wide = await s.getHistoricalPrices(
        symbol: 'TCS', startDate: DateTime(2023, 1, 1), endDate: DateTime(2024, 12, 31));
    final narrow = await s.getHistoricalPrices(
        symbol: 'TCS', startDate: DateTime(2024, 6, 1), endDate: DateTime(2024, 6, 30));
    final day = narrow.prices.first.date;
    final match = wide.prices.firstWhere((p) => p.date == day);
    expect(match.close, narrow.prices.first.close);
  });

  test('has multi-year history, weekdays only, positive prices', () async {
    final series = await make().getHistoricalPrices(
        symbol: 'RELIANCE',
        startDate: DateTime(2019, 1, 1),
        endDate: DateTime(2024, 12, 31));
    expect(series.prices.length, greaterThan(1400));
    expect(series.prices.every((p) => p.date.weekday <= DateTime.friday), isTrue);
    expect(series.prices.every((p) => p.close > 0), isTrue);
    const calc = StockCalculationService();
    final m = calc.computeMetrics('RELIANCE', calc.cleanSeries(series.prices))!;
    expect(m.annualizedVolatility, isNotNull);
  });

  test('ITC and TCS have missing days (different trading calendars)', () async {
    final s = make();
    final reliance = await s.getHistoricalPrices(
        symbol: 'RELIANCE', startDate: DateTime(2022, 1, 1), endDate: DateTime(2023, 12, 31));
    final itc = await s.getHistoricalPrices(
        symbol: 'ITC', startDate: DateTime(2022, 1, 1), endDate: DateTime(2023, 12, 31));
    expect(itc.prices.length, lessThan(reliance.prices.length));
  });

  test('unknown symbol throws notFound', () async {
    expect(
      () => make().getHistoricalPrices(
          symbol: 'NOPE', startDate: DateTime(2024, 1, 1), endDate: DateTime(2024, 2, 1)),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.notFound)),
    );
  });

  test('dividends: synthetic events, and missing data is explicit', () async {
    final s = make();
    final tcs = await s.getDividends(
        symbol: 'TCS', startDate: DateTime(2024, 1, 1), endDate: DateTime(2024, 12, 31));
    expect(tcs.available, isTrue);
    expect(tcs.isSynthetic, isTrue);
    expect(tcs.events.length, 4);

    final rel = await s.getDividends(
        symbol: 'RELIANCE', startDate: DateTime(2024, 1, 1), endDate: DateTime(2024, 12, 31));
    expect(rel.available, isFalse);
    expect(rel.events, isEmpty);
    expect(rel.unavailableReason, isNotNull);
  });
}
