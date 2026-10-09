part of 'habit_stats_bloc.dart';

@immutable
sealed class HabitStatsEvent {}

/// Starts listening to completions.
final class HabitsStatsInitialLoad extends HabitStatsEvent {}

/// Marks today as done for the habit, or undoes today's mark.
final class HabitCompletionToggled extends HabitStatsEvent {
  final String habitId;

  HabitCompletionToggled(this.habitId);
}

/// The calendar day changed while the app was running.
final class _HabitStatsDayChanged extends HabitStatsEvent {}
