import 'package:flutter_test/flutter_test.dart';
import 'package:stock_scope/core/errors/app_exception.dart';
import 'package:stock_scope/data/datasources/market_data_source.dart';
import 'package:stock_scope/data/repositories/stock_repository.dart';
import 'package:stock_scope/models/dividend_info.dart';
import 'package:stock_scope/models/historical_price.dart';
import 'package:stock_scope/models/price_series.dart';
import 'package:stock_scope/models/stock.dart';

class FakeSource implements MarketDataSource {
  int searchCalls = 0;
  int priceCalls = 0;
  Object? failWith;
  List<Stock> searchResult = const [Stock(symbol: 'A', companyName: 'Alpha')];

  @override
  String get name => 'Fake';
  @override
  bool get isDemo => false;
  @override
  String get historyNote => '';
  @override
  List<Stock> get suggestedStocks => const [];

  @override
  Future<List<Stock>> searchStocks(String query) async {
    searchCalls++;
    if (failWith != null) throw failWith!;
    return searchResult;
  }

  @override
  Future<PriceSeries> getHistoricalPrices({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    priceCalls++;
    if (failWith != null) throw failWith!;
    return PriceSeries(
      symbol: symbol,
      prices: [HistoricalPrice(date: startDate, close: 10)],
      basis: PriceBasis.unadjusted,
      sourceName: 'Fake',
      fetchedAt: DateTime(2025, 1, 1),
    );
  }

  @override
  Future<Stock?> getStockDetails(String symbol) async => null;

  @override
  Future<DividendResult> getDividends({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async =>
      DividendResult.unavailable(
        reason: 'n/a',
        sourceName: 'Fake',
        observedAt: DateTime(2025, 1, 1),
      );
}

void main() {
  final start = DateTime(2025, 1, 1);
  final end = DateTime(2025, 3, 1);

  test('short queries do not hit the source', () async {
    final src = FakeSource();
    final repo = StockRepository(src);
    expect(await repo.searchStocks('a'), isEmpty);
    expect(src.searchCalls, 0);
  });

  test('search results are cached', () async {
    final src = FakeSource();
    final repo = StockRepository(src);
    await repo.searchStocks('alpha');
    await repo.searchStocks('ALPHA ');
    expect(src.searchCalls, 1);
  });

  test('prices: second call is served from cache and flagged', () async {
    final src = FakeSource();
    final repo = StockRepository(src);
    final first = await repo.getPrices('A', start, end);
    final second = await repo.getPrices('A', start, end);
    expect(src.priceCalls, 1);
    expect(first.fromCache, isFalse);
    expect(second.fromCache, isTrue);
  });

  test('concurrent identical requests share one call', () async {
    final src = FakeSource();
    final repo = StockRepository(src);
    await Future.wait([
      repo.getPrices('A', start, end),
      repo.getPrices('A', start, end),
    ]);
    expect(src.priceCalls, 1);
  });

  test('cache expires after the TTL', () async {
    final src = FakeSource();
    var now = DateTime(2025, 1, 1, 10);
    final repo = StockRepository(src,
        clock: () => now, cacheTtl: const Duration(minutes: 5));
    await repo.getPrices('A', start, end);
    now = now.add(const Duration(minutes: 6));
    await repo.getPrices('A', start, end);
    expect(src.priceCalls, 2);
  });

  test('errors propagate and are not cached', () async {
    final src = FakeSource()
      ..failWith = const AppException(AppErrorType.rateLimit, 'slow down');
    final repo = StockRepository(src);
    await expectLater(
      repo.getPrices('A', start, end),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.rateLimit)),
    );
    src.failWith = null;
    final ok = await repo.getPrices('A', start, end);
    expect(ok.prices, isNotEmpty);
    expect(src.priceCalls, 2);
  });

  test('invalid date range is rejected without calling the source', () async {
    final src = FakeSource();
    final repo = StockRepository(src);
    await expectLater(
      repo.getPrices('A', end, start),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.invalidInput)),
    );
    expect(src.priceCalls, 0);
  });
}
