import 'package:flutter/foundation.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

/// Today's progress by schedule:
/// - daily habits and weekday habits due today are today's obligations;
/// - weekly-target habits are this week's goals, tracked separately;
/// - weekday habits not due today wait for their days and never count as incomplete;
/// - paused habits are not scheduled at all.
@immutable
class TodayProgress {
  /// Active habits due today, in display order.
  final List<Habit> scheduled;

  /// Active weekly-target habits.
  final List<Habit> weekly;

  /// Active weekday habits that are not scheduled today.
  final List<Habit> otherDays;

  /// Paused habits, shown separately.
  final List<Habit> paused;

  /// Habits of [scheduled] marked today.
  final int completed;

  /// Habits of [weekly] that reached this week's target.
  final int weeklyReached;

  const TodayProgress._({
    required this.scheduled,
    required this.weekly,
    required this.otherDays,
    required this.paused,
    required this.completed,
    required this.weeklyReached,
  });

  factory TodayProgress.of(
    List<Habit> habits, {
    required CalendarDay today,
    required bool Function(String habitId) isCompletedToday,
    bool Function(Habit habit)? weekTargetReached,
  }) {
    final active = habits.where((habit) => habit.isActive);
    final scheduled = active.where((habit) => habit.schedule.isDueOn(today)).toList();
    final weekly = active.where((habit) => habit.schedule.type == ScheduleType.weeklyTarget).toList();
    return TodayProgress._(
      scheduled: scheduled,
      weekly: weekly,
      otherDays: active
          .where((habit) => habit.schedule.type == ScheduleType.weekdays && !habit.schedule.isDueOn(today))
          .toList(),
      paused: habits.where((habit) => !habit.isActive).toList(),
      completed: scheduled.where((habit) => isCompletedToday(habit.id)).length,
      weeklyReached: weekTargetReached == null ? 0 : weekly.where(weekTargetReached).length,
    );
  }

  int get total => scheduled.length;

  bool get hasHabits => scheduled.isNotEmpty || weekly.isNotEmpty || otherDays.isNotEmpty || paused.isNotEmpty;

  /// Every obligation of today is done; weekly goals do not hold this back.
  bool get allDone => total > 0 && completed == total;

  /// 0–1; 0 when nothing is due today.
  double get fraction => total == 0 ? 0 : completed / total;
}
