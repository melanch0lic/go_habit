import 'package:flutter/foundation.dart';
import 'package:go_habit/core/utils/calendar_day.dart';

/// Weekly consistency (`weekly_consistency_v1`), the same rule the server ranks by
/// (`public._community_scores` on the server):
///
/// - the week runs from Monday to today (the user's local calendar date);
/// - a day is eligible from the latest of: week start, join day, the day the habit
///   was created (UTC, as on the server) — up to and including today;
/// - every day is scheduled, because habits are daily;
/// - each eligible day counts once if it has a completion;
/// - a paused habit is not scored.
///
/// Used for the user's own progress on the device, which may include completions that
/// have not been synchronized yet. Rankings always come from the server.
@immutable
class WeeklyConsistency {
  final int completedDays;
  final int eligibleDays;

  const WeeklyConsistency({required this.completedDays, required this.eligibleDays});

  static const notScored = WeeklyConsistency(completedDays: 0, eligibleDays: 0);

  bool get isScored => eligibleDays > 0;

  /// 0–100 with full precision; null without eligible days.
  double? get percentage => isScored ? completedDays * 100 / eligibleDays : null;

  /// Monday of the week containing [day]. Calendar arithmetic, so daylight-saving
  /// transitions do not shift the boundary.
  static CalendarDay weekStart(CalendarDay day) =>
      day.addDays(-(DateTime.utc(day.year, day.month, day.day).weekday - DateTime.monday));

  /// The day the server treats as the habit's creation day.
  static CalendarDay creationDay(DateTime createdAt) {
    final utc = createdAt.toUtc();
    return CalendarDay(utc.year, utc.month, utc.day);
  }

  /// First eligible day of the current week; may be after [today].
  static CalendarDay eligibleFrom({
    required CalendarDay today,
    required CalendarDay joinedOn,
    required DateTime habitCreatedAt,
  }) =>
      [weekStart(today), joinedOn, creationDay(habitCreatedAt)].reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

  factory WeeklyConsistency.compute({
    required CalendarDay today,
    required CalendarDay joinedOn,
    required DateTime habitCreatedAt,
    required Iterable<CalendarDay> completedDays,
    bool habitActive = true,
  }) {
    if (!habitActive) return notScored;
    final start = eligibleFrom(today: today, joinedOn: joinedOn, habitCreatedAt: habitCreatedAt);
    final eligible = today.differenceInDays(start) + 1;
    if (eligible <= 0) return notScored;
    // A set: duplicate records of one day count once.
    final completed = completedDays.where((day) => day.compareTo(start) >= 0 && day.compareTo(today) <= 0).toSet();
    return WeeklyConsistency(completedDays: completed.length, eligibleDays: eligible);
  }

  @override
  bool operator ==(Object other) =>
      other is WeeklyConsistency && other.completedDays == completedDays && other.eligibleDays == eligibleDays;

  @override
  int get hashCode => Object.hash(completedDays, eligibleDays);

  @override
  String toString() => 'WeeklyConsistency($completedDays/$eligibleDays)';
}
