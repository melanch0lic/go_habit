import 'package:flutter/foundation.dart';
import 'package:go_habit/core/utils/calendar_day.dart';

/// How often a habit is meant to be done. Stored on the habit as `schedule_type`,
/// `weekly_target` and `schedule_days` (see the `habit` table).
enum ScheduleType {
  /// Every day.
  daily('daily'),

  /// A number of times per week (1–7), on any days.
  weeklyTarget('weekly_target'),

  /// On selected weekdays.
  weekdays('weekdays');

  /// Value in the database.
  final String wire;

  const ScheduleType(this.wire);

  static ScheduleType parse(String? value) =>
      ScheduleType.values.where((type) => type.wire == value).firstOrNull ?? ScheduleType.daily;
}

@immutable
class HabitSchedule {
  final ScheduleType type;

  /// Completions per week, 1–7; only for [ScheduleType.weeklyTarget].
  final int? weeklyTarget;

  /// [DateTime.monday] … [DateTime.sunday]; only for [ScheduleType.weekdays].
  final Set<int> weekdays;

  const HabitSchedule._(this.type, {this.weeklyTarget, this.weekdays = const {}});

  static const daily = HabitSchedule._(ScheduleType.daily);

  factory HabitSchedule.weeklyTarget(int target) {
    if (target < 1 || target > 7) throw ArgumentError.value(target, 'target', 'must be 1–7');
    return HabitSchedule._(ScheduleType.weeklyTarget, weeklyTarget: target);
  }

  factory HabitSchedule.weekdays(Set<int> days) {
    if (days.isEmpty || days.any((d) => d < DateTime.monday || d > DateTime.sunday)) {
      throw ArgumentError.value(days, 'days', 'must be one or more weekdays');
    }
    return HabitSchedule._(ScheduleType.weekdays, weekdays: Set.unmodifiable(days));
  }

  /// Reads stored columns; anything inconsistent falls back to daily rather than
  /// failing (the database constraint normally prevents it).
  factory HabitSchedule.fromStorage({String? type, int? weeklyTarget, int? daysMask}) {
    switch (ScheduleType.parse(type)) {
      case ScheduleType.weeklyTarget when weeklyTarget != null && weeklyTarget >= 1 && weeklyTarget <= 7:
        return HabitSchedule.weeklyTarget(weeklyTarget);
      case ScheduleType.weekdays when daysMask != null && daysMask > 0 && daysMask < 128:
        return HabitSchedule.weekdays({
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            if (daysMask & (1 << (day - 1)) != 0) day,
        });
      case _:
        return daily;
    }
  }

  /// Bit (weekday - 1) per selected day; null unless [ScheduleType.weekdays].
  int? get daysMask =>
      type == ScheduleType.weekdays ? weekdays.fold<int>(0, (mask, day) => mask | (1 << (day - 1))) : null;

  /// Whether the habit is an obligation for [day]: daily habits every day, weekday
  /// habits on their days. Weekly targets are never a specific day's obligation.
  bool isDueOn(CalendarDay day) => switch (type) {
        ScheduleType.daily => true,
        ScheduleType.weekdays => weekdays.contains(day.weekday),
        ScheduleType.weeklyTarget => false,
      };

  /// Whether a completion on [day] counts: any day, except unselected weekdays.
  bool countsOn(CalendarDay day) => type != ScheduleType.weekdays || weekdays.contains(day.weekday);

  /// Selected weekdays in calendar order.
  List<int> get sortedWeekdays => weekdays.toList()..sort();

  @override
  bool operator ==(Object other) =>
      other is HabitSchedule &&
      other.type == type &&
      other.weeklyTarget == weeklyTarget &&
      setEquals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(type, weeklyTarget, Object.hashAllUnordered(weekdays));

  @override
  String toString() => 'HabitSchedule($type, target: $weeklyTarget, days: $sortedWeekdays)';
}
