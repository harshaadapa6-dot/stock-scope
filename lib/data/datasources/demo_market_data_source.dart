import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/dividend_info.dart';
import '../../models/historical_price.dart';
import '../../models/price_series.dart';
import '../../models/stock.dart';
import 'market_data_source.dart';

class _DemoProfile {
  const _DemoProfile({
    required this.symbol,
    required this.name,
    required this.startPrice,
    required this.annualDrift,
    required this.annualVol,
    required this.seed,
    this.skipEvery,
    this.dividendMonths = const [],
    this.dividendAmount = 0,
    this.dividendDataAvailable = true,
  });

  final String symbol;
  final String name;
  final double startPrice;
  final double annualDrift;
  final double annualVol;
  final int seed;

  /// Observations whose weekday index is divisible by this are omitted, which
  /// gives the stock a different "trading calendar" from the others and
  /// exercises missing-data handling.
  final int? skipEvery;
  final List<int> dividendMonths;
  final double dividendAmount;

  /// false => the demo provider "does not supply" dividends for this symbol.
  final bool dividendDataAvailable;
}

/// Deterministic, clearly synthetic market data for demos and tests.
///
/// Prices are produced by a seeded random walk over weekdays starting at a
/// fixed anchor date, so the same date always yields the same price. Nothing
/// here is real market data.
class DemoMarketDataSource implements MarketDataSource {
  DemoMarketDataSource({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, List<HistoricalPrice>> _generated = {};
  final Map<String, DateTime> _generatedThrough = {};

  static final DateTime anchorDate = DateTime(2015, 1, 1);
  static const String sourceLabel = 'Synthetic demo data';

  static const List<_DemoProfile> _profiles = [
    _DemoProfile(
      symbol: 'RELIANCE',
      name: 'Reliance Industries',
      startPrice: 480,
      annualDrift: 0.14,
      annualVol: 0.26,
      seed: 11,
      dividendDataAvailable: false,
    ),
    _DemoProfile(
      symbol: 'TCS',
      name: 'Tata Consultancy Services',
      startPrice: 1250,
      annualDrift: 0.12,
      annualVol: 0.22,
      seed: 23,
      skipEvery: 53,
      dividendMonths: [1, 4, 7, 10],
      dividendAmount: 9.0,
    ),
    _DemoProfile(
      symbol: 'INFY',
      name: 'Infosys',
      startPrice: 520,
      annualDrift: 0.11,
      annualVol: 0.25,
      seed: 37,
      dividendMonths: [5, 11],
      dividendAmount: 7.5,
    ),
    _DemoProfile(
      symbol: 'HDFCBANK',
      name: 'HDFC Bank',
      startPrice: 900,
      annualDrift: 0.09,
      annualVol: 0.21,
      seed: 41,
      dividendMonths: [6],
      dividendAmount: 14.0,
    ),
    _DemoProfile(
      symbol: 'ITC',
      name: 'ITC Limited',
      startPrice: 170,
      annualDrift: 0.10,
      annualVol: 0.19,
      seed: 59,
      skipEvery: 29,
      dividendMonths: [2, 6],
      dividendAmount: 5.0,
    ),
  ];

  @override
  String get name => sourceLabel;

  @override
  bool get isDemo => true;

  @override
  String get historyNote =>
      'Demo data is synthetic and generated from a fixed seed, with history '
      'from January 2015. Some stocks intentionally have missing days.';

  Stock _toStock(_DemoProfile p) => Stock(
        symbol: p.symbol,
        companyName: p.name,
        exchange: 'NSE',
        currency: 'INR',
        description:
            'Synthetic demo series. Not an actual market price or forecast.',
      );

  @override
  List<Stock> get suggestedStocks => _profiles.map(_toStock).toList();

  _DemoProfile? _find(String symbol) {
    for (final p in _profiles) {
      if (p.symbol == symbol.toUpperCase()) return p;
    }
    return null;
  }

  @override
  Future<List<Stock>> searchStocks(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final p in _profiles)
        if (p.symbol.toLowerCase().contains(q) ||
            p.name.toLowerCase().contains(q))
          _toStock(p),
    ];
  }

  @override
  Future<Stock?> getStockDetails(String symbol) async {
    final p = _find(symbol);
    return p == null ? null : _toStock(p);
  }

  // ---- deterministic generator -------------------------------------------

  /// Seeded linear congruential generator -> uniform [0, 1).
  static double Function() _lcg(int seed) {
    var state = (seed * 2654435761) & 0xFFFFFFFF;
    return () {
      state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
      return state / 4294967296.0;
    };
  }

  /// Approximately standard-normal via the Irwin-Hall sum of 12 uniforms.
  static double _normal(double Function() u) {
    var sum = 0.0;
    for (var i = 0; i < 12; i++) {
      sum += u();
    }
    return sum - 6.0;
  }

  List<HistoricalPrice> _seriesFor(_DemoProfile p, DateTime through) {
    final cacheKey = p.symbol;
    final cached = _generated[cacheKey];
    final cachedThrough = _generatedThrough[cacheKey];
    if (cached != null &&
        cachedThrough != null &&
        !through.isAfter(cachedThrough)) {
      return cached;
    }
    final u = _lcg(p.seed);
    final dt = 1 / AppConstants.tradingDaysPerYear;
    final out = <HistoricalPrice>[];
    var price = p.startPrice;
    var day = anchorDate;
    var index = 0;
    while (!day.isAfter(through)) {
      if (day.weekday <= DateTime.friday) {
        index++;
        final z = _normal(u);
        final r = p.annualDrift * dt + p.annualVol * math.sqrt(dt) * z;
        price = math.max(1.0, price * (1 + r));
        final skip = p.skipEvery != null && index % p.skipEvery! == 0;
        if (!skip) {
          out.add(HistoricalPrice(
            date: day,
            close: double.parse(price.toStringAsFixed(2)),
            volume: (1000000 + u() * 4000000).roundToDouble(),
          ));
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    _generated[cacheKey] = out;
    _generatedThrough[cacheKey] = through;
    return out;
  }

  @override
  Future<PriceSeries> getHistoricalPrices({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final p = _find(symbol);
    if (p == null) {
      throw AppException(
        AppErrorType.notFound,
        'No demo data exists for "$symbol".',
        hint: 'Demo symbols: ${_profiles.map((e) => e.symbol).join(', ')}.',
      );
    }
    final today = dateOnly(_clock());
    final through = dateOnly(endDate).isAfter(today) ? today : dateOnly(endDate);
    // Always generate through "today": the walk is a prefix-stable sequence,
    // so every request sees the same price for the same date.
    final all = _seriesFor(p, today);
    final s = dateOnly(startDate);
    final e = through;
    final filtered = [
      for (final h in all)
        if (!h.date.isBefore(s) && !h.date.isAfter(e)) h,
    ];
    return PriceSeries(
      symbol: p.symbol,
      prices: filtered,
      basis: PriceBasis.unadjusted,
      currency: 'INR',
      sourceName: sourceLabel,
      fetchedAt: _clock(),
      isDemo: true,
    );
  }

  @override
  Future<DividendResult> getDividends({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final p = _find(symbol);
    final now = _clock();
    if (p == null) {
      throw AppException(
        AppErrorType.notFound,
        'No demo data exists for "$symbol".',
      );
    }
    if (!p.dividendDataAvailable) {
      return DividendResult.unavailable(
        reason: 'The demo provider does not supply dividend data for this '
            'symbol. (This is a deliberate demonstration of missing data.)',
        sourceName: sourceLabel,
        observedAt: now,
        isSynthetic: true,
      );
    }
    final s = dateOnly(startDate);
    final e = dateOnly(endDate);
    final today = dateOnly(now);
    final events = <DividendInfo>[];
    for (var year = s.year; year <= e.year; year++) {
      for (final month in p.dividendMonths) {
        final ex = DateTime(year, month, 15);
        if (ex.isBefore(s) || ex.isAfter(e) || ex.isAfter(today)) continue;
        events.add(DividendInfo(
          amount: p.dividendAmount,
          exDividendDate: ex,
          paymentDate: DateTime(ex.year, ex.month, ex.day + 20),
          currency: 'INR',
          source: '$sourceLabel (synthetic)',
        ));
      }
    }
    return DividendResult(
      available: true,
      events: events,
      sourceName: sourceLabel,
      observedAt: now,
      isSynthetic: true,
    );
  }
}
