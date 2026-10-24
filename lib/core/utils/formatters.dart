import 'package:intl/intl.dart';

/// Display formatting helpers. Missing values render as an em dash, never as
/// a fake zero.
class Fmt {
  Fmt._();

  static const String missing = '\u2014';

  static String currencySymbol(String? code) {
    switch (code) {
      case 'INR':
        return '\u20B9';
      case 'USD':
        return '\$';
      case 'EUR':
        return '\u20AC';
      case 'GBP':
        return '\u00A3';
      case 'JPY':
        return '\u00A5';
      case null:
        return '';
      default:
        return '$code ';
    }
  }

  static NumberFormat _money(String? currency) => currency == 'INR'
      ? NumberFormat('#,##,##0.00', 'en_IN') // lakh/crore grouping
      : NumberFormat('#,##0.00', 'en_US');

  /// Formats a price with currency symbol, e.g. the rupee sign + "1,234.50".
  static String price(double? value, {String? currency}) {
    if (value == null || !value.isFinite) return missing;
    final sign = value < 0 ? '-' : '';
    return '$sign${currencySymbol(currency)}${_money(currency).format(value.abs())}';
  }

  /// Signed price delta, e.g. "+" + currency symbol + "10.00".
  static String priceChange(double? value, {String? currency}) {
    if (value == null || !value.isFinite) return missing;
    final sign = value > 0 ? '+' : (value < 0 ? '-' : '');
    return '$sign${currencySymbol(currency)}${_money(currency).format(value.abs())}';
  }

  /// [value] is already in percentage points (10.0 => "+10.00%").
  static String percent(double? value, {int digits = 2, bool signed = true}) {
    if (value == null || !value.isFinite) return missing;
    final text = value.abs().toStringAsFixed(digits);
    final isZero = double.parse(text) == 0;
    final sign = isZero ? '' : (value > 0 ? (signed ? '+' : '') : '-');
    return '$sign$text%';
  }

  /// [fraction] is a ratio (0.1 => "10.00%").
  static String fractionAsPercent(double? fraction,
      {int digits = 2, bool signed = false}) {
    if (fraction == null || !fraction.isFinite) return missing;
    return percent(fraction * 100, digits: digits, signed: signed);
  }

  static String compact(double value) =>
      NumberFormat.compact(locale: 'en_US').format(value);

  static String number(double? value, {int digits = 2}) {
    if (value == null || !value.isFinite) return missing;
    final pattern = digits <= 0 ? '#,##0' : '#,##0.${'0' * digits}';
    return NumberFormat(pattern, 'en_US').format(value);
  }

  static String date(DateTime? d) =>
      d == null ? missing : DateFormat('dd MMM yyyy').format(d);

  static String dateShort(DateTime d) => DateFormat('dd MMM').format(d);

  static String monthYear(DateTime d) => DateFormat('MMM yy').format(d);

  static String dateTime(DateTime? d) =>
      d == null ? missing : DateFormat('dd MMM yyyy, HH:mm').format(d);

  /// API-style date, e.g. 2025-03-31.
  static String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
