import 'package:flutter/foundation.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

/// What one streak unit means for a schedule.
enum StreakUnit {
  /// Consecutive completed days (daily habits).
  days,

  /// Consecutive weeks that reached the weekly target.
  weeks,

  /// Consecutive completed scheduled weekdays.
  occurrences,
}

@immutable
class HabitStreak {
  final int count;
  final StreakUnit unit;

  const HabitStreak(this.count, this.unit);

  @override
  bool operator ==(Object other) => other is HabitStreak && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'HabitStreak($count ${unit.name})';
}

/// The current streak, derived from the completion history and the schedule; it is
/// never stored. The period in progress (today, or the current week) never breaks a
/// streak, it only extends it once successful. Completions before [resetOn] are
/// ignored: a schedule type change starts a new streak without deleting history.
///
/// Days are local calendar days and weeks run Monday–Sunday, so time zones and
/// daylight-saving changes do not affect the result. Repeated records of one day
/// count once. Changing parameters within a type (another target or other weekdays)
/// re-evaluates the whole history with the new rule.
HabitStreak computeStreak({
  required HabitSchedule schedule,
  required Iterable<CalendarDay> completedDays,
  required CalendarDay today,
  CalendarDay? resetOn,
}) {
  final done = {
    for (final day in completedDays)
      if (resetOn == null || day.compareTo(resetOn) >= 0) day,
  };
  bool beforeReset(CalendarDay day) => resetOn != null && day.compareTo(resetOn) < 0;

  switch (schedule.type) {
    case ScheduleType.daily:
      var cursor = done.contains(today) ? today : today.addDays(-1);
      var count = 0;
      while (done.contains(cursor)) {
        count++;
        cursor = cursor.addDays(-1);
      }
      return HabitStreak(count, StreakUnit.days);

    case ScheduleType.weeklyTarget:
      final target = schedule.weeklyTarget!;
      int doneIn(CalendarDay monday) => List.generate(7, (i) => monday.addDays(i))
          .where((day) => day.compareTo(today) <= 0 && done.contains(day))
          .length;
      final current = today.weekStart;
      // The current week only counts once its target is reached.
      var count = doneIn(current) >= target ? 1 : 0;
      var monday = current.addDays(-7);
      while (!beforeReset(monday.addDays(6)) && doneIn(monday) >= target) {
        count++;
        monday = monday.addDays(-7);
      }
      return HabitStreak(count, StreakUnit.weeks);

    case ScheduleType.weekdays:
      var count = 0;
      // Today is in progress: a mark extends the streak, its absence does not break it.
      if (schedule.isDueOn(today) && done.contains(today)) count++;
      var cursor = today.addDays(-1);
      // At least one weekday is selected, so a missed one is found within a week of
      // the earliest completion.
      while (!beforeReset(cursor)) {
        if (schedule.isDueOn(cursor)) {
          if (!done.contains(cursor)) break;
          count++;
        }
        cursor = cursor.addDays(-1);
      }
      return HabitStreak(count, StreakUnit.occurrences);
  }
}

/// This week's progress towards the schedule, for display.
@immutable
class WeekProgress {
  final int done;

  /// Daily: days so far this week (from creation at the earliest); weekly target:
  /// the target; weekdays: selected days this week.
  final int goal;

  const WeekProgress(this.done, this.goal);

  bool get reached => goal > 0 && done >= goal;

  @override
  bool operator ==(Object other) => other is WeekProgress && other.done == done && other.goal == goal;

  @override
  int get hashCode => Object.hash(done, goal);

  @override
  String toString() => 'WeekProgress($done/$goal)';
}

/// Completions before [resetOn] are left out, like in [computeStreak], so a week shown
/// as reached is a week the streak counts.
WeekProgress weekProgress({
  required HabitSchedule schedule,
  required Iterable<CalendarDay> completedDays,
  required CalendarDay today,
  DateTime? createdAt,
  CalendarDay? resetOn,
}) {
  final done = {
    for (final day in completedDays)
      if (resetOn == null || day.compareTo(resetOn) >= 0) day,
  };
  final monday = today.weekStart;
  final week = List.generate(7, monday.addDays);
  final completedSoFar = week.where((day) => day.compareTo(today) <= 0 && done.contains(day));
  switch (schedule.type) {
    case ScheduleType.daily:
      final created = createdAt == null ? null : CalendarDay.fromDateTime(createdAt);
      final from = created != null && created.compareTo(monday) > 0 ? created : monday;
      final goal = today.differenceInDays(from) + 1;
      return WeekProgress(completedSoFar.where((day) => day.compareTo(from) >= 0).length, goal < 0 ? 0 : goal);
    case ScheduleType.weeklyTarget:
      final target = schedule.weeklyTarget!;
      // Extra completions do not count beyond the target.
      final count = completedSoFar.length;
      return WeekProgress(count > target ? target : count, target);
    case ScheduleType.weekdays:
      return WeekProgress(
        completedSoFar.where(schedule.countsOn).length,
        week.where(schedule.isDueOn).length,
      );
  }
}
