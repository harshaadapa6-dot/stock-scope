import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../models/dividend_info.dart';
import '../../models/price_series.dart';
import '../../models/stock.dart';
import '../datasources/market_data_source.dart';

class _Cached<T> {
  _Cached(this.value, this.storedAt);
  final T value;
  final DateTime storedAt;
}

/// Single entry point for market data used by providers.
///
/// Adds: input validation, a short-lived in-memory cache (cache hits are
/// flagged via [PriceSeries.fromCache]), and de-duplication of identical
/// in-flight requests. Failed requests are never cached, and no data is ever
/// substituted when the source fails.
class StockRepository {
  StockRepository(
    this._source, {
    DateTime Function()? clock,
    Duration? cacheTtl,
  })  : _clock = clock ?? DateTime.now,
        _ttl = cacheTtl ?? AppConstants.cacheTtl;

  final MarketDataSource _source;
  final DateTime Function() _clock;
  final Duration _ttl;

  final Map<String, _Cached<List<Stock>>> _searchCache = {};
  final Map<String, _Cached<PriceSeries>> _priceCache = {};
  final Map<String, _Cached<DividendResult>> _dividendCache = {};
  final Map<String, Future<PriceSeries>> _inFlight = {};

  String get sourceName => _source.name;
  bool get isDemo => _source.isDemo;
  String get historyNote => _source.historyNote;
  List<Stock> get suggestedStocks => _source.suggestedStocks;

  bool _fresh(DateTime storedAt) => _clock().difference(storedAt) < _ttl;

  Future<List<Stock>> searchStocks(String query) async {
    final q = query.trim();
    if (q.length < AppConstants.minSearchLength) return const [];
    final key = q.toLowerCase();
    final hit = _searchCache[key];
    if (hit != null && _fresh(hit.storedAt)) return hit.value;
    final result = await _source.searchStocks(q);
    _searchCache[key] = _Cached(result, _clock());
    return result;
  }

  Future<PriceSeries> getPrices(
    String symbol,
    DateTime start,
    DateTime end,
  ) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (!s.isBefore(e)) {
      return Future.error(const AppException(
        AppErrorType.invalidInput,
        'The start date must be before the end date.',
      ));
    }
    final key = '$symbol|${Fmt.isoDate(s)}|${Fmt.isoDate(e)}';
    final hit = _priceCache[key];
    if (hit != null && _fresh(hit.storedAt)) {
      return Future.value(hit.value.copyWith(fromCache: true));
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _source
        .getHistoricalPrices(symbol: symbol, startDate: s, endDate: e)
        .then((series) {
      _priceCache[key] = _Cached(series, _clock());
      return series;
    }).whenComplete(() => _inFlight.remove(key));
    _inFlight[key] = future;
    return future;
  }

  Future<Stock?> getStock(String symbol) => _source.getStockDetails(symbol);

  Future<DividendResult> getDividends(
    String symbol,
    DateTime start,
    DateTime end,
  ) async {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (!s.isBefore(e)) {
      throw const AppException(
        AppErrorType.invalidInput,
        'The start date must be before the end date.',
      );
    }
    final key = '$symbol|${Fmt.isoDate(s)}|${Fmt.isoDate(e)}';
    final hit = _dividendCache[key];
    if (hit != null && _fresh(hit.storedAt)) return hit.value;
    final result =
        await _source.getDividends(symbol: symbol, startDate: s, endDate: e);
    _dividendCache[key] = _Cached(result, _clock());
    return result;
  }
}
