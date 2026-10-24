/// A single dividend event. Only fields the provider supplied are set.
class DividendInfo {
  const DividendInfo({
    required this.amount,
    this.exDividendDate,
    this.paymentDate,
    this.currency,
    this.source,
  });

  final double amount;
  final DateTime? exDividendDate;
  final DateTime? paymentDate;
  final String? currency;
  final String? source;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        if (exDividendDate != null)
          'exDividendDate': exDividendDate!.toIso8601String(),
        if (paymentDate != null) 'paymentDate': paymentDate!.toIso8601String(),
        if (currency != null) 'currency': currency,
        if (source != null) 'source': source,
      };

  factory DividendInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return DividendInfo(
      amount: (json['amount'] as num).toDouble(),
      exDividendDate: parse(json['exDividendDate']),
      paymentDate: parse(json['paymentDate']),
      currency: json['currency'] as String?,
      source: json['source'] as String?,
    );
  }
}

/// The outcome of asking a provider for dividends.
///
/// Distinguishes three states that must never be conflated:
///  * [available] == false  -> provider cannot say (data MISSING)
///  * [available] && events.isEmpty -> provider reports no events in range
///  * [available] && events.isNotEmpty -> events reported
class DividendResult {
  const DividendResult({
    required this.available,
    required this.events,
    required this.sourceName,
    required this.observedAt,
    this.unavailableReason,
    this.isSynthetic = false,
  });

  const DividendResult.unavailable({
    required String reason,
    required String sourceName,
    required DateTime observedAt,
    bool isSynthetic = false,
  }) : this(
          available: false,
          events: const [],
          sourceName: sourceName,
          observedAt: observedAt,
          unavailableReason: reason,
          isSynthetic: isSynthetic,
        );

  final bool available;
  final List<DividendInfo> events;
  final String sourceName;
  final DateTime observedAt;
  final String? unavailableReason;
  final bool isSynthetic;
}

/// Aggregated dividends for a window. [total] is null when it cannot be
/// computed reliably; [note] explains why.
class DividendSummary {
  const DividendSummary({
    required this.eventCount,
    required this.total,
    this.currency,
    this.note,
  });

  final int eventCount;
  final double? total;
  final String? currency;
  final String? note;
}
