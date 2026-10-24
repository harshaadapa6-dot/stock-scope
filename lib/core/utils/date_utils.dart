import '../constants/app_constants.dart';

/// Strips the time component.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days between two dates, immune to DST offsets.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Preset comparison windows.
enum ComparisonPeriod {
  oneMonth('1M', '1 month', 1),
  threeMonths('3M', '3 months', 3),
  sixMonths('6M', '6 months', 6),
  oneYear('1Y', '1 year', 12),
  threeYears('3Y', '3 years', 36),
  fiveYears('5Y', '5 years', 60);

  const ComparisonPeriod(this.shortLabel, this.label, this.months);

  final String shortLabel;
  final String label;
  final int months;

  DateTime startFor(DateTime end) {
    final e = dateOnly(end);
    return DateTime(e.year, e.month - months, e.day);
  }
}

/// A validated-on-demand historical date range.
class DateRangeSelection {
  const DateRangeSelection({
    required this.start,
    required this.end,
    this.period,
  });

  factory DateRangeSelection.forPeriod(ComparisonPeriod period,
      {DateTime? today}) {
    final end = dateOnly(today ?? DateTime.now());
    return DateRangeSelection(
      start: period.startFor(end),
      end: end,
      period: period,
    );
  }

  final DateTime start;
  final DateTime end;

  /// Null for custom ranges.
  final ComparisonPeriod? period;

  bool get isCustom => period == null;

  /// Returns a user-facing problem description, or null if the range is valid.
  String? validate({DateTime? today}) {
    final now = dateOnly(today ?? DateTime.now());
    if (!start.isBefore(end)) {
      return 'The start date must be before the end date.';
    }
    if (end.isAfter(now)) {
      return 'The end date cannot be in the future.';
    }
    if (daysBetween(start, end) < AppConstants.minRangeDays) {
      return 'Choose a range of at least ${AppConstants.minRangeDays} days.';
    }
    if (start.year < 1990) {
      return 'Start dates before 1990 are not supported.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DateRangeSelection &&
      other.start == start &&
      other.end == end &&
      other.period == period;

  @override
  int get hashCode => Object.hash(start, end, period);
}
