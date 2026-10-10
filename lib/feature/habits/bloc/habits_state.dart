part of 'habits_bloc.dart';

sealed class HabitsState {
  final List<Habit> habits;

  const HabitsState({this.habits = const []});
}

final class HabitsInitial extends HabitsState {}

final class HabitsLoading extends HabitsState {
  @override
  final List<Habit> habits;

  HabitsLoading(this.habits);
}

class HabitsLoadSuccess extends HabitsState {
  @override
  final List<Habit> habits;

  HabitsLoadSuccess(this.habits);
}

class HabitsOperationSuccess extends HabitsState {
  @override
  final List<Habit> habits;
  final String message;

  HabitsOperationSuccess({required this.habits, required this.message});
}

/// What the user tried to do when an operation failed.
enum HabitOperation { add, update, delete, toggleActive, unknown }

class HabitsOperationFailure extends HabitsState {
  @override
  final List<Habit> habits;

  /// Technical details for logs; the UI shows a message for [operation].
  final String error;
  final HabitOperation operation;

  HabitsOperationFailure({required this.habits, required this.error, this.operation = HabitOperation.unknown});
}

/// The habits could not be read from the device at all.
final class HabitsLoadFailure extends HabitsState {
  final String error;

  HabitsLoadFailure(this.error);
}
