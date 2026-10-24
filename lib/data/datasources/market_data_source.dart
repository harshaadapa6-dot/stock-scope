import '../../models/dividend_info.dart';
import '../../models/price_series.dart';
import '../../models/stock.dart';

/// Abstraction over a market data provider. Implementations must throw
/// `AppException` for expected failures and must never fabricate data.
abstract class MarketDataSource {
  /// Human-readable provider name shown in the UI.
  String get name;

  /// True only for the synthetic demo source.
  bool get isDemo;

  /// Plain-language note about history/market limits of this provider.
  String get historyNote;

  /// Sample symbols shown on the dashboard. No prices are implied.
  List<Stock> get suggestedStocks;

  Future<List<Stock>> searchStocks(String query);

  Future<PriceSeries> getHistoricalPrices({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Stock?> getStockDetails(String symbol);

  Future<DividendResult> getDividends({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  });
}
