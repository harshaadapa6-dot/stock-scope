import 'package:flutter_test/flutter_test.dart';
import 'package:stock_scope/core/errors/app_exception.dart';
import 'package:stock_scope/data/datasources/remote_market_data_source.dart';
import 'package:stock_scope/models/price_series.dart';

/// Tests use canned JSON only. They never touch the network and need no key.
RemoteMarketDataSource source(
  Map<String, dynamic> Function(String path, Map<String, dynamic> q) respond, {
  String? key = 'test-key',
}) {
  return RemoteMarketDataSource(
    fetch: (path, q) async => respond(path, q),
    apiKey: key,
    clock: () => DateTime(2025, 6, 1),
  );
}

Matcher throwsType(AppErrorType t) =>
    throwsA(isA<AppException>().having((e) => e.type, 'type', t));

void main() {
  final start = DateTime(2025, 1, 1);
  final end = DateTime(2025, 2, 1);

  test('missing API key fails clearly without a request', () async {
    var called = false;
    final s = source((p, q) {
      called = true;
      return {};
    }, key: '');
    await expectLater(s.searchStocks('apple'), throwsType(AppErrorType.invalidKey));
    expect(called, isFalse);
  });

  test('search parses results and builds SYMBOL:EXCHANGE ids', () async {
    final s = source((p, q) {
      expect(p, '/symbol_search');
      expect(q['apikey'], 'test-key');
      return {
        'status': 'ok',
        'data': [
          {'symbol': 'RELIANCE', 'instrument_name': 'Reliance Industries', 'exchange': 'NSE', 'currency': 'INR'},
          {'symbol': 'RELIANCE', 'instrument_name': 'Reliance Industries', 'exchange': 'NSE'},
          {'symbol': 'X'},
          {'nope': 1},
        ],
      };
    });
    final r = await s.searchStocks('reliance');
    expect(r.map((e) => e.symbol), ['RELIANCE:NSE', 'X']);
    expect(r.first.displaySymbol, 'RELIANCE');
    expect(r.first.currency, 'INR');
  });

  test('history: parses values, sorts ascending, skips bad rows', () async {
    final s = source((p, q) {
      expect(p, '/time_series');
      expect(q['symbol'], 'TCS');
      expect(q['exchange'], 'NSE');
      return {
        'status': 'ok',
        'meta': {'currency': 'INR'},
        'values': [
          {'datetime': '2025-01-03', 'close': '102.5', 'volume': '10'},
          {'datetime': '2025-01-02', 'close': '100.0'},
          {'datetime': 'bad', 'close': '1'},
          {'datetime': '2025-01-04', 'close': 'abc'},
        ],
      };
    });
    final series = await s.getHistoricalPrices(
        symbol: 'TCS:NSE', startDate: start, endDate: end);
    expect(series.prices.map((p) => p.close), [100.0, 102.5]);
    expect(series.currency, 'INR');
    expect(series.basis, PriceBasis.splitAdjusted);
    expect(series.isDemo, isFalse);
  });

  test('history: "no data" error becomes an empty series', () async {
    final s = source((p, q) => {
          'status': 'error',
          'code': 400,
          'message': '**No data is available** on the specified dates.',
        });
    final series = await s.getHistoricalPrices(
        symbol: 'AAPL', startDate: start, endDate: end);
    expect(series.prices, isEmpty);
  });

  test('history: empty values list is an empty series', () async {
    final s = source((p, q) => {'status': 'ok', 'values': <dynamic>[]});
    final series = await s.getHistoricalPrices(
        symbol: 'AAPL', startDate: start, endDate: end);
    expect(series.prices, isEmpty);
  });

  test('history: malformed response throws parse error', () async {
    final s = source((p, q) => {'status': 'ok', 'values': 'oops'});
    await expectLater(
      s.getHistoricalPrices(symbol: 'AAPL', startDate: start, endDate: end),
      throwsType(AppErrorType.parse),
    );
  });

  test('rate limit (429) maps to rateLimit and is not retryable', () async {
    final s = source((p, q) =>
        {'status': 'error', 'code': 429, 'message': 'run out of API credits'});
    await expectLater(
      s.getHistoricalPrices(symbol: 'AAPL', startDate: start, endDate: end),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.rateLimit)
          .having((e) => e.retryable, 'retryable', isFalse)),
    );
  });

  test('401 maps to invalidKey', () async {
    final s = source((p, q) =>
        {'status': 'error', 'code': 401, 'message': 'apikey is incorrect'});
    await expectLater(s.searchStocks('aa'), throwsType(AppErrorType.invalidKey));
  });

  test('plan restriction on dividends gives an unavailable result', () async {
    final s = source((p, q) => {
          'status': 'error',
          'code': 403,
          'message': 'This endpoint is available on Grow plan, upgrade.',
        });
    final r = await s.getDividends(symbol: 'AAPL', startDate: start, endDate: end);
    expect(r.available, isFalse);
    expect(r.unavailableReason, isNotNull);
  });

  test('dividends parse into events', () async {
    final s = source((p, q) => {
          'meta': {'currency': 'USD'},
          'dividends': [
            {'ex_date': '2025-02-09', 'amount': 0.24},
            {'ex_date': '2025-01-09', 'amount': '0.25'},
            {'ex_date': '2025-01-10', 'amount': 'x'},
          ],
        });
    final r = await s.getDividends(symbol: 'AAPL', startDate: start, endDate: end);
    expect(r.available, isTrue);
    expect(r.events.length, 2);
    expect(r.events.first.exDividendDate, DateTime(2025, 1, 9));
    expect(r.events.first.currency, 'USD');
  });

  test('dividends: response without the dividends field is "unavailable"', () async {
    final s = source((p, q) => {'meta': {}});
    final r = await s.getDividends(symbol: 'AAPL', startDate: start, endDate: end);
    expect(r.available, isFalse);
  });

  test('network failures propagate as AppException', () async {
    final s = RemoteMarketDataSource(
      fetch: (p, q) async => throw const AppException(AppErrorType.network, 'offline'),
      apiKey: 'k',
    );
    await expectLater(s.searchStocks('aa'), throwsType(AppErrorType.network));
  });
}
