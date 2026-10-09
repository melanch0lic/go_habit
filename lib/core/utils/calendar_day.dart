import 'package:flutter/foundation.dart';

/// A calendar day in the user's local time zone, independent of time of day.
///
/// Daily habits are tracked per calendar day, not per 24-hour window: a habit
/// completed at 23:50 is not "completed today" five minutes later. Serialized as
/// `YYYY-MM-DD`, which is also the format of the `date` column in Postgres.
@immutable
class CalendarDay implements Comparable<CalendarDay> {
  final int year;
  final int month;
  final int day;

  const CalendarDay._(this.year, this.month, this.day);

  /// Normalizes out-of-range values, e.g. `CalendarDay(2026, 1, 32)` is February 1st.
  factory CalendarDay(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    return CalendarDay._(normalized.year, normalized.month, normalized.day);
  }

  /// The local calendar day of [dateTime]; UTC values are converted to local time first.
  factory CalendarDay.fromDateTime(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return CalendarDay._(local.year, local.month, local.day);
  }

  factory CalendarDay.today() => CalendarDay.fromDateTime(DateTime.now());

  /// Parses `YYYY-MM-DD`.
  factory CalendarDay.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Expected YYYY-MM-DD', value);
    }
    return CalendarDay(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  CalendarDay addDays(int days) => CalendarDay(year, month, day + days);

  /// Whole days from [other] to this day (positive if this day is later).
  int differenceInDays(CalendarDay other) =>
      DateTime.utc(year, month, day).difference(DateTime.utc(other.year, other.month, other.day)).inDays;

  /// Local midnight at the start of this day.
  DateTime toDateTime() => DateTime(year, month, day);

  String toIsoString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDay other) => differenceInDays(other).sign;

  @override
  bool operator ==(Object other) =>
      other is CalendarDay && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIsoString();
}
