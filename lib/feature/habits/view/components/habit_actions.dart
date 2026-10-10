import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/view/components/modal_bottom_sheet.dart';
import 'package:go_habit/feature/notifications/data/notification_repository.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';

enum HabitMenuAction { edit, togglePause, delete }

/// Opens the form for a new habit and adds it through [HabitsBloc].
Future<void> addHabit(BuildContext context) async {
  final bloc = context.read<HabitsBloc>();
  final draft = await HabitFormSheet.show(context, categories: _categories(context));
  if (draft == null) return;
  bloc.add(AddHabit(
    title: draft.title,
    description: draft.description,
    categoryKey: draft.categoryId,
    emojiIcon: draft.icon,
    schedule: draft.schedule,
    reminder: draft.reminder,
  ));
}

/// The habit's reminder on this device, or null where notifications are not set up.
Future<ReminderDraft?> _reminderOf(BuildContext context, String habitId) async {
  try {
    final reminders = await context.read<NotificationRepository>().getReminders();
    return switch (reminders[habitId]) { final reminder? => ReminderDraft.of(reminder), null => null };
  } on ProviderNotFoundException {
    return null;
  }
}

/// Opens the form for [habit] and saves the changes through [HabitsBloc]. The id,
/// the completion history and the paused state stay as they are. A confirmed change
/// of schedule type also starts the streak over (see HabitFormSheet).
Future<void> editHabit(BuildContext context, Habit habit) async {
  final bloc = context.read<HabitsBloc>();
  final categories = _categories(context);
  final reminder = await _reminderOf(context, habit.id);
  if (!context.mounted) return;
  final draft = await HabitFormSheet.show(context, categories: categories, habit: habit, reminder: reminder);
  if (draft == null) return;
  bloc.add(UpdateHabit(
    habit.id,
    draft.title,
    draft.description,
    draft.categoryId,
    draft.icon,
    draft.schedule,
    draft.resetStreak,
  ));
  if (draft.reminder != reminder) bloc.add(SetHabitReminder(habit.id, draft.reminder));
}

/// Asks before deleting [habit]. Offers pausing instead, since deleting also removes
/// the habit's history on every device.
Future<void> deleteHabit(BuildContext context, Habit habit) async {
  final bloc = context.read<HabitsBloc>();
  final l10n = context.l10n;
  final choice = await showDialog<HabitMenuAction>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.themeOf.cardColor,
      title: Text(l10n.habits_delete_title(habit.title)),
      content: Text(l10n.habits_delete_message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        if (habit.isActive)
          TextButton(
            onPressed: () => Navigator.pop(context, HabitMenuAction.togglePause),
            child: Text(l10n.habits_pause),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, HabitMenuAction.delete),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: Text(l10n.habits_delete),
        ),
      ],
    ),
  );
  switch (choice) {
    case HabitMenuAction.delete:
      bloc.add(DeleteHabit(habit.id));
    case HabitMenuAction.togglePause:
      bloc.add(ToggleActiveHabit(habit.id));
    case HabitMenuAction.edit || null:
      break;
  }
}

List<HabitCategory> _categories(BuildContext context) => switch (context.read<HabitCategoryBloc>().state) {
      HabitCategoryLoaded(:final categories) || HabitCategoryError(:final categories) => categories,
      _ => const [],
    };
