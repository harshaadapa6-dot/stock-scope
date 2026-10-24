/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'StockScope';
  static const String tagline = 'Compare. Analyze. Understand.';
  static const String version = '1.0.0';

  /// Conventional number of trading days per year used to annualize volatility.
  static const int tradingDaysPerYear = 252;

  static const int minCompareStocks = 2;
  static const int maxCompareStocks = 5;
  static const int minRangeDays = 7;

  static const Duration searchDebounce = Duration(milliseconds: 450);
  static const int minSearchLength = 2;
  static const Duration cacheTtl = Duration(minutes: 15);

  static const String twelveDataBaseUrl = 'https://api.twelvedata.com';
  static const String apiKeyEnvName = 'TWELVE_DATA_API_KEY';

  static const String disclaimer =
      'StockScope is an educational tool. Information shown is historical, may '
      'be delayed, incomplete or synthetic (in demo mode) and is not '
      'investment advice. Past performance does not predict future results. '
      'StockScope cannot place trades and is not affiliated with any broker, '
      'exchange or financial institution.';
}
