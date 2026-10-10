import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/weekly_consistency.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

/// Whether a membership's ranked habit is available on this device.
enum RankedHabitStatus { none, missing, available }

extension RankedHabitOf on CommunityMembership {
  /// The ranked habit among the user's habits, if any.
  Habit? rankedHabitIn(List<Habit> habits) => habits.where((habit) => habit.id == habitId).firstOrNull;

  RankedHabitStatus rankedHabitStatus(List<Habit> habits) => habitId == null
      ? RankedHabitStatus.none
      : rankedHabitIn(habits) == null
          ? RankedHabitStatus.missing
          : RankedHabitStatus.available;
}

/// The user's own weekly progress in a community, from the habits and completions
/// on this device (including marks that are not synchronized yet). Drawn on the dark
/// habit-card surface.
class MembershipProgress extends StatelessWidget {
  final CommunityMembership membership;

  const MembershipProgress({required this.membership, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textColor = Colors.white.withValues(alpha: 0.85);
    final habits = context.select<HabitsBloc, List<Habit>>((bloc) => bloc.state.habits);
    final habit = membership.rankedHabitIn(habits);
    final stats = context.watch<HabitStatsBloc>().state;

    Widget line(String text, {IconData? icon}) => Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: textColor), const SizedBox(width: 6)],
            Expanded(child: Text(text, style: TextStyle(color: textColor, fontSize: 13))),
          ],
        );

    switch (membership.rankedHabitStatus(habits)) {
      case RankedHabitStatus.none:
        return line(l10n.community_not_ranked, icon: Icons.leaderboard_outlined);
      case RankedHabitStatus.missing:
        return line(l10n.community_ranked_habit_missing, icon: Icons.help_outline);
      case RankedHabitStatus.available:
        break;
    }
    if (habit == null || stats is! HabitStatsLoaded) return const SizedBox.shrink();

    final completedDays = stats.completedDaysOf(habit.id);
    final progress = WeeklyConsistency.compute(
      today: stats.today,
      joinedOn: membership.joinedOn,
      habitCreatedAt: habit.createdAt,
      completedDays: completedDays,
      habitActive: habit.isActive,
      schedule: habit.schedule,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(l10n.community_ranked_habit(habit.title), icon: Icons.leaderboard_outlined),
        const SizedBox(height: 8),
        if (!habit.isActive)
          line(l10n.community_habit_paused, icon: Icons.pause_circle_outline)
        else ...[
          WeekStrip(
            today: stats.today,
            eligibleFrom: WeeklyConsistency.eligibleFrom(
              today: stats.today,
              joinedOn: membership.joinedOn,
              habitCreatedAt: habit.createdAt,
            ),
            completedDays: completedDays.toSet(),
            schedule: habit.schedule,
          ),
          const SizedBox(height: 6),
          line(
            progress.isScored
                ? l10n.community_week_progress(progress.completedDays, progress.eligibleDays)
                : l10n.community_week_progress_none,
          ),
        ],
      ],
    );
  }
}

/// Seven pixel squares, Monday to Sunday: completed, missed (eligible), or not counted.
/// Days off of a weekday schedule are not counted.
class WeekStrip extends StatelessWidget {
  final CalendarDay today;
  final CalendarDay eligibleFrom;
  final Set<CalendarDay> completedDays;
  final HabitSchedule schedule;

  const WeekStrip({
    required this.today,
    required this.eligibleFrom,
    required this.completedDays,
    this.schedule = HabitSchedule.daily,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final green = context.theme.commonColors.green100;
    final monday = WeeklyConsistency.weekStart(today);
    // Material weekday labels start on Sunday.
    final labels = MaterialLocalizations.of(context).narrowWeekdays;

    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Builder(builder: (context) {
                final day = monday.addDays(i);
                final counted = day.compareTo(eligibleFrom) >= 0 && day.compareTo(today) <= 0 && schedule.countsOn(day);
                final done = counted && completedDays.contains(day);
                return Column(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: done ? green : Colors.white.withValues(alpha: counted ? 0.18 : 0.06),
                        borderRadius: BorderRadius.circular(3),
                        border: day == today ? Border.all(color: Colors.white70) : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(labels[(i + 1) % 7], style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}
