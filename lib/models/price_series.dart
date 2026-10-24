import 'historical_price.dart';

/// How the prices in a series were adjusted. Series of different bases must
/// never be mixed in one comparison.
enum PriceBasis {
  /// Provider supplies dividend- and split-adjusted closes (adjustedClose).
  adjusted,

  /// Closes adjusted for splits only.
  splitAdjusted,

  /// Raw closes with no adjustment information.
  unadjusted;

  String get label {
    switch (this) {
      case PriceBasis.adjusted:
        return 'Adjusted close (splits and distributions, per provider)';
      case PriceBasis.splitAdjusted:
        return 'Split-adjusted close (not adjusted for dividends)';
      case PriceBasis.unadjusted:
        return 'Closing price (no adjustment information)';
    }
  }

  String get shortLabel {
    switch (this) {
      case PriceBasis.adjusted:
        return 'Adjusted';
      case PriceBasis.splitAdjusted:
        return 'Split-adjusted';
      case PriceBasis.unadjusted:
        return 'Unadjusted';
    }
  }
}

/// Historical prices plus the metadata needed to describe them honestly.
class PriceSeries {
  const PriceSeries({
    required this.symbol,
    required this.prices,
    required this.basis,
    required this.sourceName,
    required this.fetchedAt,
    this.currency,
    this.isDemo = false,
    this.fromCache = false,
  });

  final String symbol;
  final List<HistoricalPrice> prices;
  final PriceBasis basis;
  final String? currency;
  final String sourceName;

  /// When the data was obtained from the source (never invented).
  final DateTime fetchedAt;
  final bool isDemo;
  final bool fromCache;

  /// Calculations use adjustedClose only for [PriceBasis.adjusted].
  bool get useAdjusted => basis == PriceBasis.adjusted;

  PriceSeries copyWith({bool? fromCache}) => PriceSeries(
        symbol: symbol,
        prices: prices,
        basis: basis,
        sourceName: sourceName,
        fetchedAt: fetchedAt,
        currency: currency,
        isDemo: isDemo,
        fromCache: fromCache ?? this.fromCache,
      );
}
