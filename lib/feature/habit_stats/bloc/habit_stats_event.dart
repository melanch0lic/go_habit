part of 'habit_stats_bloc.dart';

@immutable
sealed class HabitStatsEvent {}

/// Starts listening to completions.
final class HabitsStatsInitialLoad extends HabitStatsEvent {}

/// Marks today as done for the habit, or undoes today's mark.
final class HabitCompletionToggled extends HabitStatsEvent {
  final String habitId;

  /// The state the user asked for. Repeated taps carry the same intent, so they
  /// cannot flip the mark back and forth. Null toggles the current state.
  final bool? completed;

  HabitCompletionToggled(this.habitId, {this.completed});
}

/// The calendar day changed while the app was running.
final class _HabitStatsDayChanged extends HabitStatsEvent {}
