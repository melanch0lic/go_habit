part of 'habits_bloc.dart';

sealed class HabitsEvent {}

final class LoadHabits extends HabitsEvent {
  final List<Habit> habits;

  LoadHabits(this.habits);
}

final class AddHabit extends HabitsEvent {
  final String title;
  final String description;
  final String categoryKey;
  final String emojiIcon;
  final HabitSchedule schedule;
  AddHabit({
    required this.title,
    required this.description,
    required this.categoryKey,
    required this.emojiIcon,
    this.schedule = HabitSchedule.daily,
  });
}

final class UpdateHabit extends HabitsEvent {
  final String id;
  final String title;
  final String description;
  final String? categoryId;

  /// New emoji; null keeps the current one.
  final String? icon;

  /// New schedule; null keeps the current one.
  final HabitSchedule? schedule;

  /// The user confirmed that the schedule type changes: the streak starts over today.
  /// Never set without that confirmation.
  final bool resetStreak;
  UpdateHabit(this.id, this.title, this.description,
      [this.categoryId, this.icon, this.schedule, this.resetStreak = false]);
}

final class DeleteHabit extends HabitsEvent {
  final String id;
  DeleteHabit(this.id);
}

final class ToggleActiveHabit extends HabitsEvent {
  final String id;
  ToggleActiveHabit(this.id);
}

final class InitializeHabits extends HabitsEvent {}
