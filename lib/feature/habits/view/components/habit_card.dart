import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/widget/habit_completion_button.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/habit_actions.dart';
import 'package:go_habit/feature/habits/view/components/modal_bottom_sheet.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';

/// A habit in the list: icon, name, category and streak, this week's marks, the
/// completion control and a menu with edit, pause and delete. Tapping the card edits
/// the habit; completing never needs another screen.
class HabitCard extends StatelessWidget {
  final Habit habit;
  final HabitCategory habitCategory;

  const HabitCard({required this.habit, required this.habitCategory, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final color = hexToColor(habitCategory.color);
    final green = context.theme.commonColors.green100;
    final stats = context.watch<HabitStatsBloc>().state;
    final loaded = stats is HabitStatsLoaded ? stats : null;
    final completed = loaded?.isCompletedToday(habit.id) ?? false;
    final streak = loaded == null ? null : l10n.streakText(loaded.streakOf(habit));
    final active = habit.isActive;
    final schedule = habit.schedule;
    // Weekday habits are only marked on their days; daily and weekly ones any day.
    final canComplete =
        active && (schedule.type != ScheduleType.weekdays || loaded == null || schedule.isDueOn(loaded.today));
    final description = habit.description?.trim();
    final progress = !active || loaded == null
        ? null
        : schedule.type == ScheduleType.weekdays && !schedule.isDueOn(loaded.today)
            ? '${l10n.habits_not_today} · ${l10n.weekProgressText(schedule, loaded.weekProgressOf(habit))}'
            : l10n.weekProgressText(schedule, loaded.weekProgressOf(habit));

    final meta = [
      habitCategory.name,
      if (schedule.type != ScheduleType.daily) l10n.scheduleShort(schedule),
      if (!active) l10n.habits_paused_label,
      if (active && streak != null) streak,
    ].join(' · ');

    return Semantics(
      container: true,
      label: [
        habit.title,
        meta,
        if (progress != null) progress,
        if (canComplete) completed ? l10n.habits_done_today : l10n.habits_not_done_today,
      ].join(', '),
      child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
        opacity: active ? 1 : 0.6,
        child: Material(
          color: completed ? Color.alphaBlend(green.withValues(alpha: 0.08), theme.cardColor) : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => editHabit(context, habit),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
                      child: Text(habit.icon ?? '🎯', style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                          ),
                          if (description != null && description.isNotEmpty)
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // The category color, adjusted until it reads as small text on the card.
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color.readableOn(theme.cardColor),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (progress != null) ...[
                            const SizedBox(height: 2),
                            Text(progress,
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                          ],
                          if (active && loaded != null) ...[
                            const SizedBox(height: 6),
                            _WeekMarks(
                              color: color,
                              schedule: schedule,
                              today: loaded.today,
                              completedDays: loaded.completedDaysOf(habit.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (canComplete)
                    HabitCompletionButton(
                      habitId: habit.id,
                      round: true,
                      // Non-text UI needs 3:1 against the card.
                      color: color.readableOn(theme.cardColor, ratio: 3),
                      completedColor: green,
                      iconColor: Colors.white,
                    ),
                  HabitMenuButton(habit: habit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// This week, Monday to Sunday, as small pixels: marked days filled, today underlined.
/// For a weekday schedule, its days are outlined and the days off faded.
class _WeekMarks extends StatelessWidget {
  final Color color;
  final HabitSchedule schedule;
  final CalendarDay today;
  final List<CalendarDay> completedDays;

  const _WeekMarks({required this.color, required this.schedule, required this.today, required this.completedDays});

  @override
  Widget build(BuildContext context) {
    final done = completedDays.toSet();
    final empty = context.themeOf.dividerColor;
    final monday = today.weekStart;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final day = monday.addDays(i);
            final counts = schedule.countsOn(day);
            final marked = done.contains(day) && counts;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: marked ? color : (counts ? empty : empty.withValues(alpha: 0.35)),
                      // Only a weekday schedule tells due days from days off.
                      border: schedule.type == ScheduleType.weekdays && counts && !marked
                          ? Border.all(color: color.withValues(alpha: 0.6))
                          : null,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(width: 8, height: 2, color: day == today ? color : Colors.transparent),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// The "⋮" menu of a habit: edit, pause or resume, delete.
class HabitMenuButton extends StatelessWidget {
  final Habit habit;

  const HabitMenuButton({required this.habit, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<HabitMenuAction>(
      tooltip: l10n.habits_actions(habit.title),
      icon: const Icon(Icons.more_vert),
      onOpened: AppHaptics.selection,
      onSelected: (action) => switch (action) {
        HabitMenuAction.edit => editHabit(context, habit),
        HabitMenuAction.togglePause => context.read<HabitsBloc>().add(ToggleActiveHabit(habit.id)),
        HabitMenuAction.delete => deleteHabit(context, habit),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: HabitMenuAction.edit,
          child: ListTile(
              leading: const Icon(Icons.edit_outlined), title: Text(l10n.habits_edit), contentPadding: EdgeInsets.zero),
        ),
        PopupMenuItem(
          value: HabitMenuAction.togglePause,
          child: ListTile(
            leading: Icon(habit.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
            title: Text(habit.isActive ? l10n.habits_pause : l10n.habits_resume),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: HabitMenuAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text(l10n.habits_delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
