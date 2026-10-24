/// One daily observation. [adjustedClose] and [volume] are nullable because
/// providers may not supply them; null means "not provided", never zero.
class HistoricalPrice {
  const HistoricalPrice({
    required this.date,
    required this.close,
    this.adjustedClose,
    this.volume,
  });

  final DateTime date;
  final double close;
  final double? adjustedClose;
  final double? volume;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'close': close,
        if (adjustedClose != null) 'adjustedClose': adjustedClose,
        if (volume != null) 'volume': volume,
      };

  factory HistoricalPrice.fromJson(Map<String, dynamic> json) {
    return HistoricalPrice(
      date: DateTime.parse(json['date'] as String),
      close: (json['close'] as num).toDouble(),
      adjustedClose: (json['adjustedClose'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
    );
  }
}

/// A cleaned (date, value) pair used by all calculations.
class PricePoint {
  const PricePoint(this.date, this.value);

  final DateTime date;
  final double value;

  @override
  String toString() => 'PricePoint($date, $value)';
}
