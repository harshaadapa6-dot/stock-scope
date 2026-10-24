import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../models/dividend_info.dart';
import '../../models/historical_price.dart';
import '../../models/price_series.dart';
import '../../models/stock.dart';
import 'market_data_source.dart';

/// Twelve Data (https://twelvedata.com) integration.
///
/// Endpoints used (see https://twelvedata.com/docs):
///  * GET /symbol_search  -> { "data": [ {symbol, instrument_name, exchange,
///                              currency, ...} ], "status": "ok" }
///  * GET /time_series    -> { "meta": {symbol, currency, exchange, ...},
///                              "values": [ {datetime, open, high, low,
///                              close, volume} ], "status": "ok" }
///  * GET /quote          -> { name, symbol, exchange, currency, ... }
///  * GET /dividends      -> { "meta": {...}, "dividends": [ {ex_date,
///                              amount} ] }
/// Errors are returned as { "code": <int>, "message": <text>,
/// "status": "error" }.
///
/// IMPORTANT: this implementation was written against the public
/// documentation but could NOT be exercised against the live API in the
/// environment where the project was generated (no network access). Verify
/// with your own key before relying on it, and see README "Known limitations".
///
/// Prices are requested with adjust=splits, so the series basis is
/// [PriceBasis.splitAdjusted] (not dividend-adjusted).
class RemoteMarketDataSource implements MarketDataSource {
  RemoteMarketDataSource({
    required JsonFetcher fetch,
    required String? apiKey,
    DateTime Function()? clock,
  })  : _fetch = fetch,
        _apiKey = apiKey,
        _clock = clock ?? DateTime.now;

  final JsonFetcher _fetch;
  final String? _apiKey;
  final DateTime Function() _clock;

  static const String providerName = 'Twelve Data';

  @override
  String get name => providerName;

  @override
  bool get isDemo => false;

  @override
  String get historyNote =>
      'Available history, exchanges (for example NSE/BSE) and requests per '
      'minute depend on your Twelve Data plan. Dividend data may require a '
      'paid plan.';

  @override
  List<Stock> get suggestedStocks => const [
        Stock(symbol: 'AAPL:NASDAQ', companyName: 'Apple Inc.', exchange: 'NASDAQ'),
        Stock(
            symbol: 'MSFT:NASDAQ',
            companyName: 'Microsoft Corporation',
            exchange: 'NASDAQ'),
        Stock(symbol: 'KO:NYSE', companyName: 'The Coca-Cola Company', exchange: 'NYSE'),
        Stock(
            symbol: 'RELIANCE:NSE',
            companyName: 'Reliance Industries',
            exchange: 'NSE'),
        Stock(
            symbol: 'TCS:NSE',
            companyName: 'Tata Consultancy Services',
            exchange: 'NSE'),
      ];

  // ---- request plumbing ---------------------------------------------------

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    final key = _apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw const AppException(
        AppErrorType.invalidKey,
        'No market data API key is configured.',
        hint: 'Add TWELVE_DATA_API_KEY to your .env file, or switch to demo '
            'mode in Settings.',
      );
    }
    final body = await _fetch(path, {...query, 'apikey': key});
    _throwIfError(body);
    return body;
  }

  /// Splits "SYMBOL:EXCHANGE" into request parameters.
  Map<String, dynamic> _symbolParams(String id) {
    final i = id.lastIndexOf(':');
    if (i <= 0) return {'symbol': id};
    return {'symbol': id.substring(0, i), 'exchange': id.substring(i + 1)};
  }

  void _throwIfError(Map<String, dynamic> body) {
    final status = body['status'];
    final code = body['code'];
    final isError = status == 'error' || (code is num && code >= 400);
    if (!isError) return;

    final c = code is num ? code.toInt() : 0;
    final message = (body['message'] ?? '').toString();
    final lower = message.toLowerCase();

    if (c == 401) {
      throw const AppException(
        AppErrorType.invalidKey,
        'The market data API key was rejected.',
        hint: 'Check TWELVE_DATA_API_KEY in your .env file, or switch to demo '
            'mode in Settings.',
      );
    }
    if (c == 429) {
      throw const AppException(
        AppErrorType.rateLimit,
        'The data provider rate limit has been reached.',
        hint: 'Wait about a minute before trying again, or switch to demo '
            'mode.',
      );
    }
    if (c == 403 ||
        lower.contains('upgrade') ||
        lower.contains('your plan') ||
        lower.contains('available starting with')) {
      throw AppException(
        AppErrorType.planRestricted,
        'This data is not included in your current provider plan.',
        hint: message.isEmpty ? null : _truncate(message),
      );
    }
    if (lower.contains('no data')) {
      throw const AppException(
        AppErrorType.noData,
        'The provider has no data for this request.',
      );
    }
    if (c == 404 || lower.contains('not found') || lower.contains('symbol')) {
      throw const AppException(
        AppErrorType.notFound,
        'The provider could not find this symbol.',
        hint: 'Search again and pick a result from the list.',
      );
    }
    throw AppException(
      AppErrorType.unknown,
      'The data provider reported an error.',
      hint: message.isEmpty ? null : _truncate(message),
    );
  }

  String? _str(Object? v) => v is String ? v : null;

  String _truncate(String s) => s.length > 160 ? '${s.substring(0, 157)}...' : s;

  // ---- MarketDataSource ---------------------------------------------------

  @override
  Future<List<Stock>> searchStocks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final body = await _get('/symbol_search', {'symbol': q, 'outputsize': 25});
    final data = body['data'];
    if (data is! List) {
      throw const AppException(
        AppErrorType.parse,
        'The data provider returned an unexpected search response.',
      );
    }
    final seen = <String>{};
    final results = <Stock>[];
    for (final item in data) {
      if (item is! Map) continue;
      final symbol = item['symbol'];
      if (symbol is! String || symbol.isEmpty) continue;
      final exchange = _str(item['exchange']);
      final id = (exchange == null || exchange.isEmpty) ? symbol : '$symbol:$exchange';
      if (!seen.add(id)) continue;
      results.add(Stock(
        symbol: id,
        companyName: _str(item['instrument_name']) ?? symbol,
        exchange: exchange,
        currency: _str(item['currency']),
      ));
    }
    return results;
  }

  @override
  Future<PriceSeries> getHistoricalPrices({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    Map<String, dynamic> body;
    try {
      body = await _get('/time_series', {
        ..._symbolParams(symbol),
        'interval': '1day',
        'start_date': Fmt.isoDate(startDate),
        'end_date': Fmt.isoDate(endDate),
        'outputsize': 5000,
        'order': 'asc',
        'adjust': 'splits',
      });
    } on AppException catch (e) {
      if (e.type == AppErrorType.noData) {
        return _emptySeries(symbol);
      }
      rethrow;
    }

    final values = body['values'];
    if (values is! List) {
      throw const AppException(
        AppErrorType.parse,
        'The data provider returned an unexpected price response.',
      );
    }
    final prices = <HistoricalPrice>[];
    for (final row in values) {
      if (row is! Map) continue;
      final dateText = row['datetime'];
      final date = dateText is String && dateText.length >= 10
          ? DateTime.tryParse(dateText.substring(0, 10))
          : null;
      final close = double.tryParse('${row['close']}');
      if (date == null || close == null || !close.isFinite) continue;
      prices.add(HistoricalPrice(
        date: DateTime(date.year, date.month, date.day),
        close: close,
        volume: double.tryParse('${row['volume']}'),
      ));
    }
    prices.sort((a, b) => a.date.compareTo(b.date));

    final meta = body['meta'];
    final currency = meta is Map && meta['currency'] is String
        ? meta['currency'] as String
        : null;
    return PriceSeries(
      symbol: symbol,
      prices: prices,
      basis: PriceBasis.splitAdjusted,
      currency: currency,
      sourceName: providerName,
      fetchedAt: _clock(),
    );
  }

  PriceSeries _emptySeries(String symbol) => PriceSeries(
        symbol: symbol,
        prices: const [],
        basis: PriceBasis.splitAdjusted,
        sourceName: providerName,
        fetchedAt: _clock(),
      );

  @override
  Future<Stock?> getStockDetails(String symbol) async {
    final body = await _get('/quote', _symbolParams(symbol));
    final name = body['name'];
    if (name is! String) return null;
    return Stock(
      symbol: symbol,
      companyName: name,
      exchange: _str(body['exchange']),
      currency: _str(body['currency']),
    );
  }

  @override
  Future<DividendResult> getDividends({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final now = _clock();
    Map<String, dynamic> body;
    try {
      body = await _get('/dividends', {
        ..._symbolParams(symbol),
        'start_date': Fmt.isoDate(startDate),
        'end_date': Fmt.isoDate(endDate),
      });
    } on AppException catch (e) {
      switch (e.type) {
        case AppErrorType.planRestricted:
          return DividendResult.unavailable(
            reason: 'Dividend data is not included in your provider plan.',
            sourceName: providerName,
            observedAt: now,
          );
        case AppErrorType.notFound:
          return DividendResult.unavailable(
            reason: 'The provider has no dividend data for this symbol.',
            sourceName: providerName,
            observedAt: now,
          );
        case AppErrorType.noData:
          return DividendResult(
            available: true,
            events: const [],
            sourceName: providerName,
            observedAt: now,
          );
        default:
          rethrow;
      }
    }

    final list = body['dividends'];
    if (list is! List) {
      return DividendResult.unavailable(
        reason: 'The provider response did not include dividend information.',
        sourceName: providerName,
        observedAt: now,
      );
    }
    final meta = body['meta'];
    final currency = meta is Map && meta['currency'] is String
        ? meta['currency'] as String
        : null;
    final events = <DividendInfo>[];
    for (final item in list) {
      if (item is! Map) continue;
      final amount = double.tryParse('${item['amount']}');
      if (amount == null || !amount.isFinite) continue;
      final exText = item['ex_date'];
      final ex = exText is String ? DateTime.tryParse(exText) : null;
      events.add(DividendInfo(
        amount: amount,
        exDividendDate: ex == null ? null : DateTime(ex.year, ex.month, ex.day),
        currency: currency,
        source: providerName,
      ));
    }
    events.sort((a, b) {
      final ad = a.exDividendDate;
      final bd = b.exDividendDate;
      if (ad == null || bd == null) return 0;
      return ad.compareTo(bd);
    });
    return DividendResult(
      available: true,
      events: events,
      sourceName: providerName,
      observedAt: now,
    );
  }
}
