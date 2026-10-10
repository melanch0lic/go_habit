import 'package:flutter/foundation.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

/// Weekly consistency, the same rule the server uses (`public._habit_period_counts`):
///
/// - weeks run Monday to Sunday (the user's local calendar dates);
/// - a day is eligible from the latest of: week start, join day, the day the habit
///   was created (UTC, as on the server);
/// - daily habits: every eligible day is one scheduled action; each counts once;
/// - selected weekdays: only the selected days in that range are actions;
/// - weekly target: the target, prorated when the eligible part starts after Monday
///   (`ceil(target × days from start to Sunday / 7)`); marks beyond it do not count;
/// - a paused habit is not scored.
///
/// [WeeklyConsistency.compute] is the current week up to today (live progress on the
/// device, which may include completions not synchronized yet);
/// [WeeklyConsistency.finishedWeek] is a whole finished week, as the community ranking
/// scores it. Rankings themselves always come from the server.
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

  /// The current week from its eligible start up to [today].
  factory WeeklyConsistency.compute({
    required CalendarDay today,
    required CalendarDay joinedOn,
    required DateTime habitCreatedAt,
    required Iterable<CalendarDay> completedDays,
    bool habitActive = true,
    HabitSchedule schedule = HabitSchedule.daily,
  }) {
    if (!habitActive) return notScored;
    return WeeklyConsistency._score(
      start: eligibleFrom(today: today, joinedOn: joinedOn, habitCreatedAt: habitCreatedAt),
      end: today,
      completedDays: completedDays,
      schedule: schedule,
    );
  }

  /// The whole week starting [weekStart] (a Monday), from its eligible start to Sunday.
  factory WeeklyConsistency.finishedWeek({
    required CalendarDay weekStart,
    required CalendarDay joinedOn,
    required DateTime habitCreatedAt,
    required Iterable<CalendarDay> completedDays,
    bool habitActive = true,
    HabitSchedule schedule = HabitSchedule.daily,
  }) {
    if (!habitActive) return notScored;
    final start = [weekStart, joinedOn, creationDay(habitCreatedAt)].reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return WeeklyConsistency._score(
        start: start, end: weekStart.addDays(6), completedDays: completedDays, schedule: schedule);
  }

  /// Actions over [start] .. [end], a range within one Monday–Sunday week.
  factory WeeklyConsistency._score({
    required CalendarDay start,
    required CalendarDay end,
    required Iterable<CalendarDay> completedDays,
    required HabitSchedule schedule,
  }) {
    final span = end.differenceInDays(start) + 1;
    if (span <= 0) return notScored;
    final range = List.generate(span, start.addDays);
    // A set: duplicate records of one day count once.
    final completed = completedDays.where((day) => day.compareTo(start) >= 0 && day.compareTo(end) <= 0).toSet();
    switch (schedule.type) {
      case ScheduleType.daily:
        return WeeklyConsistency(completedDays: completed.length, eligibleDays: span);
      case ScheduleType.weekdays:
        final scheduled = range.where(schedule.isDueOn).toSet();
        if (scheduled.isEmpty) return notScored;
        return WeeklyConsistency(
          completedDays: completed.intersection(scheduled).length,
          eligibleDays: scheduled.length,
        );
      case ScheduleType.weeklyTarget:
        final daysLeftInWeek = weekStart(start).addDays(6).differenceInDays(start) + 1;
        final expected = (schedule.weeklyTarget! * daysLeftInWeek / 7).ceil();
        return WeeklyConsistency(
          completedDays: completed.length > expected ? expected : completed.length,
          eligibleDays: expected,
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WeeklyConsistency && other.completedDays == completedDays && other.eligibleDays == eligibleDays;

  @override
  int get hashCode => Object.hash(completedDays, eligibleDays);

  @override
  String toString() => 'WeeklyConsistency($completedDays/$eligibleDays)';
}
