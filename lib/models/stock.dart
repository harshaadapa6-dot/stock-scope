/// A tradable instrument.
///
/// [symbol] is the provider-ready identifier and is the unique key. For the
/// remote provider it may be "SYMBOL:EXCHANGE" (e.g. "RELIANCE:NSE") so the
/// right listing is requested; use [displaySymbol] for the UI.
class Stock {
  const Stock({
    required this.symbol,
    required this.companyName,
    this.exchange,
    this.currency,
    this.description,
  });

  final String symbol;
  final String companyName;
  final String? exchange;
  final String? currency;
  final String? description;

  String get displaySymbol {
    final i = symbol.indexOf(':');
    return i > 0 ? symbol.substring(0, i) : symbol;
  }

  Stock copyWith({
    String? companyName,
    String? exchange,
    String? currency,
    String? description,
  }) {
    return Stock(
      symbol: symbol,
      companyName: companyName ?? this.companyName,
      exchange: exchange ?? this.exchange,
      currency: currency ?? this.currency,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'companyName': companyName,
        if (exchange != null) 'exchange': exchange,
        if (currency != null) 'currency': currency,
        if (description != null) 'description': description,
      };

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] as String,
      companyName: (json['companyName'] as String?) ?? json['symbol'] as String,
      exchange: json['exchange'] as String?,
      currency: json['currency'] as String?,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Stock && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() => 'Stock($symbol)';
}
