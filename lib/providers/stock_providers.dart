import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/utils/date_utils.dart';
import '../data/datasources/demo_market_data_source.dart';
import '../data/datasources/market_data_source.dart';
import '../data/datasources/remote_market_data_source.dart';
import '../data/repositories/stock_repository.dart';
import '../models/dividend_info.dart';
import '../models/historical_price.dart';
import '../models/price_series.dart';
import '../models/stock.dart';
import '../models/stock_comparison.dart';
import '../services/comparison_builder.dart';
import '../services/stock_calculation_service.dart';
import 'settings_provider.dart';

// ---------------------------------------------------------------------------
// Data source / repository
// ---------------------------------------------------------------------------

final marketDataSourceProvider = Provider<MarketDataSource>((ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.dataMode));
  if (mode == DataMode.demo) return DemoMarketDataSource();
  final client = ApiClient();
  ref.onDispose(client.close);
  return RemoteMarketDataSource(
    fetch: client.getJson,
    apiKey: ref.watch(apiKeyProvider),
  );
});

/// A new repository (and therefore an empty cache) is created whenever the
/// data source changes.
final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.watch(marketDataSourceProvider)),
);

final isDemoProvider =
    Provider<bool>((ref) => ref.watch(stockRepositoryProvider).isDemo);

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

/// Results for an already-debounced query. Only the newest query is watched by
/// the UI, so stale responses from older queries are never displayed.
final searchResultsProvider =
    FutureProvider.autoDispose.family<List<Stock>, String>((ref, query) async {
  final repo = ref.watch(stockRepositoryProvider);
  final market = ref.watch(settingsProvider.select((s) => s.preferredMarket));
  final results = await repo.searchStocks(query);
  if (market == PreferredMarket.any) return results;
  // Preferred market first (stable order otherwise); nothing is hidden.
  return [
    ...results.where((s) => market.matches(s.exchange)),
    ...results.where((s) => !market.matches(s.exchange)),
  ];
});

// ---------------------------------------------------------------------------
// Comparison setup
// ---------------------------------------------------------------------------

enum AddResult { added, duplicate, limitReached }

class SelectedStocksNotifier extends Notifier<List<Stock>> {
  @override
  List<Stock> build() {
    // Symbols differ between demo and live sources, so reset on switch.
    ref.watch(settingsProvider.select((s) => s.dataMode));
    return const [];
  }

  AddResult add(Stock stock) {
    if (state.any((s) => s.symbol == stock.symbol)) return AddResult.duplicate;
    if (state.length >= 5) return AddResult.limitReached;
    state = [...state, stock];
    return AddResult.added;
  }

  void remove(Stock stock) {
    state = [
      for (final s in state)
        if (s.symbol != stock.symbol) s,
    ];
  }

  void setAll(List<Stock> stocks) {
    final seen = <String>{};
    state = [
      for (final s in stocks)
        if (seen.add(s.symbol)) s,
    ].take(5).toList();
  }

  void clear() => state = const [];
}

final selectedStocksProvider =
    NotifierProvider<SelectedStocksNotifier, List<Stock>>(
  SelectedStocksNotifier.new,
);

class ComparisonRangeNotifier extends Notifier<DateRangeSelection> {
  @override
  DateRangeSelection build() {
    final period = ref.read(settingsProvider).defaultPeriod;
    return DateRangeSelection.forPeriod(period);
  }

  void setPeriod(ComparisonPeriod period) =>
      state = DateRangeSelection.forPeriod(period);

  void setCustom(DateTime start, DateTime end) => state =
      DateRangeSelection(start: dateOnly(start), end: dateOnly(end));
}

final comparisonRangeProvider =
    NotifierProvider<ComparisonRangeNotifier, DateRangeSelection>(
  ComparisonRangeNotifier.new,
);

// ---------------------------------------------------------------------------
// Committed comparison + results
// ---------------------------------------------------------------------------

class ComparisonRequest {
  const ComparisonRequest({required this.stocks, required this.range});

  final List<Stock> stocks;
  final DateRangeSelection range;

  ComparisonRequest withRange(DateRangeSelection r) =>
      ComparisonRequest(stocks: stocks, range: r);
}

/// Set when the user taps "Compare Now". Changing the range on the results
/// screen updates this, which re-triggers the data fetch and recalculation.
class ComparisonRequestNotifier extends Notifier<ComparisonRequest?> {
  @override
  ComparisonRequest? build() {
    ref.watch(settingsProvider.select((s) => s.dataMode));
    return null;
  }

  void commit(List<Stock> stocks, DateRangeSelection range) =>
      state = ComparisonRequest(stocks: List.unmodifiable(stocks), range: range);

  void updateRange(DateRangeSelection range) {
    final current = state;
    if (current == null) return;
    state = current.withRange(range);
  }
}

final comparisonRequestProvider =
    NotifierProvider<ComparisonRequestNotifier, ComparisonRequest?>(
  ComparisonRequestNotifier.new,
);

enum ChartMode {
  normalized('Normalized', 'Index (start = 100)'),
  percentReturn('% return', 'Return since start (%)'),
  price('Price', 'Closing price');

  const ChartMode(this.label, this.axisLabel);
  final String label;
  final String axisLabel;
}

class ChartModeNotifier extends Notifier<ChartMode> {
  @override
  ChartMode build() => ChartMode.normalized;

  void set(ChartMode mode) => state = mode;
}

final chartModeProvider =
    NotifierProvider<ChartModeNotifier, ChartMode>(ChartModeNotifier.new);

/// Fetches prices for every requested stock and builds the comparison.
///
/// Individual stock failures are tolerated as long as at least two stocks
/// succeed; their reasons are exposed in [StockComparison.failures].
final comparisonProvider =
    FutureProvider.autoDispose<StockComparison>((ref) async {
  final request = ref.watch(comparisonRequestProvider);
  if (request == null) {
    throw const AppException(
      AppErrorType.invalidInput,
      'No comparison has been set up yet.',
      hint: 'Choose at least two stocks on the Compare tab.',
    );
  }
  final repo = ref.watch(stockRepositoryProvider);

  final outcomes = await Future.wait(request.stocks.map((stock) async {
    try {
      final series = await repo.getPrices(
        stock.symbol,
        request.range.start,
        request.range.end,
      );
      return MapEntry<String, Object>(stock.symbol, series);
    } on AppException catch (e) {
      return MapEntry<String, Object>(stock.symbol, e);
    }
  }));

  final series = <String, PriceSeries>{};
  final failures = <String, String>{};
  AppException? firstError;
  for (final outcome in outcomes) {
    final value = outcome.value;
    if (value is PriceSeries) {
      series[outcome.key] = value;
    } else if (value is AppException) {
      failures[outcome.key] = value.message;
      firstError ??= value;
    }
  }
  if (series.length < 2) {
    throw firstError ??
        const AppException(
          AppErrorType.noData,
          'Not enough price data could be loaded for this comparison.',
        );
  }

  return const ComparisonBuilder().build(
    stocks: request.stocks,
    series: series,
    range: request.range,
    failures: failures,
  );
});

// ---------------------------------------------------------------------------
// Per-stock data
// ---------------------------------------------------------------------------

/// Value-equality key for family providers (dates are compared by day).
class PriceQuery {
  PriceQuery(this.symbol, DateTime start, DateTime end)
      : start = dateOnly(start),
        end = dateOnly(end);

  final String symbol;
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is PriceQuery &&
      other.symbol == symbol &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(symbol, start, end);
}

class StockAnalysis {
  const StockAnalysis({
    required this.series,
    required this.points,
    required this.metrics,
  });

  final PriceSeries series;

  /// Cleaned, range-limited observations (chronological).
  final List<PricePoint> points;

  /// Null when there is no usable data in the range.
  final StockMetrics? metrics;
}

final stockAnalysisProvider = FutureProvider.autoDispose
    .family<StockAnalysis, PriceQuery>((ref, query) async {
  final repo = ref.watch(stockRepositoryProvider);
  final series = await repo.getPrices(query.symbol, query.start, query.end);
  const calc = StockCalculationService();
  final cleaned = calc.cleanSeries(series.prices, useAdjusted: series.useAdjusted);
  final window = calc.sliceRange(cleaned, query.start, query.end);
  return StockAnalysis(
    series: series,
    points: window,
    metrics: calc.computeMetrics(query.symbol, window),
  );
});

final dividendsProvider = FutureProvider.autoDispose
    .family<DividendResult, PriceQuery>((ref, query) async {
  final repo = ref.watch(stockRepositoryProvider);
  return repo.getDividends(query.symbol, query.start, query.end);
});

/// Optional enrichment of a stock's name/exchange/currency.
final stockDetailsProvider =
    FutureProvider.autoDispose.family<Stock?, String>((ref, symbol) async {
  final repo = ref.watch(stockRepositoryProvider);
  try {
    return await repo.getStock(symbol);
  } on AppException {
    return null; // Details are an enhancement; fall back to the known stock.
  }
});

/// Latest price and change vs the previous close for list views.
class QuoteSummary {
  const QuoteSummary({
    required this.latest,
    required this.asOf,
    required this.fromCache,
    required this.isDemo,
    required this.sourceName,
    this.previous,
    this.changePercent,
    this.currency,
  });

  final double latest;
  final double? previous;

  /// Change of the last close vs the one before it (percentage points).
  final double? changePercent;
  final DateTime asOf;
  final String? currency;
  final bool fromCache;
  final bool isDemo;
  final String sourceName;
}

final quoteProvider = FutureProvider.autoDispose
    .family<QuoteSummary, String>((ref, symbol) async {
  final repo = ref.watch(stockRepositoryProvider);
  final end = dateOnly(DateTime.now());
  final start = DateTime(end.year, end.month, end.day - 40);
  final series = await repo.getPrices(symbol, start, end);
  const calc = StockCalculationService();
  final points = calc.cleanSeries(series.prices, useAdjusted: series.useAdjusted);
  if (points.isEmpty) {
    throw const AppException(
      AppErrorType.noData,
      'No recent price data is available for this stock.',
    );
  }
  final last = points.last;
  final prev = points.length >= 2 ? points[points.length - 2] : null;
  return QuoteSummary(
    latest: last.value,
    previous: prev?.value,
    changePercent:
        prev == null ? null : calc.percentageReturn(prev.value, last.value),
    asOf: last.date,
    currency: series.currency,
    fromCache: series.fromCache,
    isDemo: series.isDemo,
    sourceName: series.sourceName,
  );
});

// ---------------------------------------------------------------------------
// Shell navigation
// ---------------------------------------------------------------------------

class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void go(int index) => state = index;
}

final navIndexProvider =
    NotifierProvider<NavIndexNotifier, int>(NavIndexNotifier.new);
