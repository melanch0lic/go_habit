part of 'habit_stats_bloc.dart';

@immutable
sealed class HabitStatsState {}

final class HabitStatsInitial extends HabitStatsState {}

class HabitStatsLoading extends HabitStatsState {}

class HabitStatsLoaded extends HabitStatsState {
  final List<HabitCompletionModel> completions;

  /// The day the UI should treat as "today".
  final CalendarDay today;

  HabitStatsLoaded(this.completions, {required this.today});

  List<CalendarDay> completedDaysOf(String habitId) => [
        for (final c in completions)
          if (c.habitId == habitId) c.completedOn
      ];

  bool isCompletedOn(String habitId, CalendarDay day) =>
      completions.any((c) => c.habitId == habitId && c.completedOn == day);

  bool isCompletedToday(String habitId) => isCompletedOn(habitId, today);

  int streakOf(String habitId) => currentStreak(completedDaysOf(habitId), today);
}

class HabitStatsError extends HabitStatsState {}
