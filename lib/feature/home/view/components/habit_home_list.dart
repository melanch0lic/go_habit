import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/ui_kit/habit_card_types.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/habit_actions.dart';
import 'package:go_habit/feature/home/bloc/habit_card_settings_bloc.dart';
import 'package:go_habit/feature/home/view/components/habit_home_card.dart';

/// Today's habits on the home screen: those due today and weekly goals. Paused habits
/// and weekday habits on their days off are left to the habits tab.
class HabitHomeList extends StatelessWidget {
  const HabitHomeList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final habitsState = context.watch<HabitsBloc>().state;
    final displayMode = context.select<HabitCardSettingsBloc, HabitCardDisplayMode>((bloc) => bloc.state.displayMode);
    final categories = switch (context.watch<HabitCategoryBloc>().state) {
      HabitCategoryLoaded(:final categories) || HabitCategoryError(:final categories) => categories,
      _ => const <HabitCategory>[],
    };

    if (habitsState is HabitsInitial || (habitsState is HabitsLoading && habitsState.habits.isEmpty)) {
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator.adaptive())),
      );
    }

    final stats = context.watch<HabitStatsBloc>().state;
    final day = stats is HabitStatsLoaded ? stats.today : CalendarDay.today();
    // Due today, plus weekly goals that can be advanced on any day.
    final today = habitsState.habits
        .where((habit) =>
            habit.isActive && (habit.schedule.isDueOn(day) || habit.schedule.type == ScheduleType.weeklyTarget))
        .toList();
    if (today.isEmpty) return const SliverToBoxAdapter(child: _NothingToday());

    return SliverList.builder(
      itemCount: today.length,
      itemBuilder: (context, index) {
        final habit = today[index];
        final category = categories.where((c) => c.id == habit.categoryId).firstOrNull ??
            HabitCategory(id: habit.categoryId, name: l10n.habits_category_other, color: '#9E9E9E');
        return HabitHomeCard(key: ValueKey(habit.id), habit: habit, category: category, displayMode: displayMode);
      },
    );
  }
}

class _NothingToday extends StatelessWidget {
  const _NothingToday();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final green = context.theme.commonColors.green100;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(l10n.habits_today_nothing, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => addHabit(context),
              style: TextButton.styleFrom(foregroundColor: green, minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.add),
              label: Text(l10n.habits_add),
            ),
          ],
        ),
      ),
    );
  }
}
