part of 'habit_stats_bloc.dart';

@immutable
sealed class HabitStatsState {}

final class HabitStatsInitial extends HabitStatsState {}

class HabitStatsLoading extends HabitStatsState {}

class HabitStatsLoaded extends HabitStatsState {
  final List<HabitCompletionModel> completions;

  /// The day the UI should treat as "today".
  final CalendarDay today;

  /// Set once when a mark for this habit could not be saved; the next state clears it.
  final String? failedHabitId;

  HabitStatsLoaded(this.completions, {required this.today, this.failedHabitId});

  List<CalendarDay> completedDaysOf(String habitId) => [
        for (final c in completions)
          if (c.habitId == habitId) c.completedOn
      ];

  bool isCompletedOn(String habitId, CalendarDay day) =>
      completions.any((c) => c.habitId == habitId && c.completedOn == day);

  bool isCompletedToday(String habitId) => isCompletedOn(habitId, today);

  /// The habit's current streak under its schedule (see [computeStreak]).
  HabitStreak streakOf(Habit habit) => computeStreak(
        schedule: habit.schedule,
        completedDays: completedDaysOf(habit.id),
        today: today,
        resetOn: habit.streakResetOn,
      );

  /// This week's progress towards the habit's schedule.
  WeekProgress weekProgressOf(Habit habit) => weekProgress(
        schedule: habit.schedule,
        completedDays: completedDaysOf(habit.id),
        today: today,
        createdAt: habit.createdAt,
        resetOn: habit.streakResetOn,
      );
}

class HabitStatsError extends HabitStatsState {}
