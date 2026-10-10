import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/today_progress.dart';
import 'package:go_habit/feature/habits/view/components/habit_actions.dart';
import 'package:go_habit/feature/habits/view/components/habit_card.dart';
import 'package:go_habit/feature/habits/view/components/today_summary.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// The habits tab: today's progress, today's habits with one-tap completion, and paused
/// habits. Editing, pausing and deleting live in each habit's menu.
class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.habits_title),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PressableScale(
              pressedScale: 0.9,
              child: IconButton.filled(
                tooltip: l10n.habits_add,
                style: IconButton.styleFrom(
                  backgroundColor: context.themeOf.colorScheme.primary,
                  foregroundColor: context.themeOf.colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.add),
                onPressed: () => addHabit(context),
              ),
            ),
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<HabitsBloc, HabitsState>(
            listenWhen: (previous, current) => current is HabitsOperationFailure,
            listener: (context, state) =>
                _showError(context, _operationError(l10n, (state as HabitsOperationFailure).operation)),
          ),
          BlocListener<HabitStatsBloc, HabitStatsState>(
            listenWhen: (previous, current) => current is HabitStatsLoaded && current.failedHabitId != null,
            listener: (context, state) => _showError(context, l10n.habits_error_completion),
          ),
        ],
        child: const _HabitsBody(),
      ),
    );
  }

  static String _operationError(AppLocalizations l10n, HabitOperation operation) => switch (operation) {
        HabitOperation.add => l10n.habits_error_add,
        HabitOperation.update => l10n.habits_error_update,
        HabitOperation.delete => l10n.habits_error_delete,
        HabitOperation.toggleActive || HabitOperation.unknown => l10n.habits_error_generic,
      };

  static void _showError(BuildContext context, String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _HabitsBody extends StatelessWidget {
  const _HabitsBody();

  @override
  Widget build(BuildContext context) {
    final habitsState = context.watch<HabitsBloc>().state;
    final stats = context.watch<HabitStatsBloc>().state;
    final categories = switch (context.watch<HabitCategoryBloc>().state) {
      HabitCategoryLoaded(:final categories) || HabitCategoryError(:final categories) => categories,
      _ => const <HabitCategory>[],
    };

    return switch (habitsState) {
      HabitsLoadFailure() => _ErrorView(onRetry: () => context.read<HabitsBloc>().add(InitializeHabits())),
      HabitsInitial() || HabitsLoading() when habitsState.habits.isEmpty => const _LoadingList(),
      _ => _HabitsContent(
          habits: habitsState.habits,
          stats: stats is HabitStatsLoaded ? stats : null,
          categories: categories,
        ),
    };
  }
}

class _HabitsContent extends StatelessWidget {
  final List<Habit> habits;
  final HabitStatsLoaded? stats;
  final List<HabitCategory> categories;

  const _HabitsContent({required this.habits, required this.stats, required this.categories});

  HabitCategory _categoryOf(Habit habit, AppLocalizations l10n) =>
      categories.where((category) => category.id == habit.categoryId).firstOrNull ??
      HabitCategory(id: habit.categoryId, name: l10n.habits_category_other, color: '#9E9E9E');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = this.stats;
    final progress = TodayProgress.of(
      habits,
      today: stats?.today ?? CalendarDay.today(),
      isCompletedToday: (id) => stats?.isCompletedToday(id) ?? false,
      weekTargetReached: (habit) => stats?.weekProgressOf(habit).reached ?? false,
    );
    if (!progress.hasHabits) return const _FirstUseEmpty();

    Widget card(Habit habit) => Padding(
          key: ValueKey(habit.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: _Appear(child: HabitCard(habit: habit, habitCategory: _categoryOf(habit, l10n))),
        );

    List<Widget> section(String title, List<Habit> habits) => [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _SectionHeader(title: title, count: habits.length)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: habits.length,
              itemBuilder: (context, index) => card(habits[index]),
            ),
          ),
        ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(
            children: [
              TodaySummary(
                progress: progress,
                today: stats?.today.toDateTime() ?? DateTime.now(),
                ready: stats != null,
              ),
              _SectionHeader(title: l10n.habits_section_today, count: progress.total),
              if (progress.scheduled.isEmpty)
                _NothingToday(
                  // The paused count explains an empty day only when nothing else is planned.
                  pausedCount: progress.weekly.isEmpty && progress.otherDays.isEmpty ? progress.paused.length : 0,
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: progress.scheduled.length,
            itemBuilder: (context, index) => card(progress.scheduled[index]),
          ),
        ),
        if (progress.weekly.isNotEmpty) ...section(l10n.habits_section_week, progress.weekly),
        if (progress.otherDays.isNotEmpty) ...section(l10n.habits_section_other_days, progress.otherDays),
        if (progress.paused.isNotEmpty) ...section(l10n.habits_section_paused, progress.paused),
        // Space for the floating navigation bar.
        SliverToBoxAdapter(child: SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = context.themeOf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('$count', style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}

/// A new card fades and slides in once; instant with reduced motion.
class _Appear extends StatelessWidget {
  final Widget child;

  const _Appear({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 8), child: child),
      ),
      child: child,
    );
  }
}

/// No habits at all yet.
class _FirstUseEmpty extends StatelessWidget {
  const _FirstUseEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final green = context.theme.commonColors.green100;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32, 24, 32, 24 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: green.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const ExcludeSemantics(child: Text('🌱', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.habits_empty_title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(l10n.habits_empty_body, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            PressableScale(
              child: FilledButton.icon(
                onPressed: () => addHabit(context),
                style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size(200, 48)),
                icon: const Icon(Icons.add),
                label: Text(l10n.habits_add),
              ),
            ),
            TextButton(
              onPressed: () => context.go(CommunityRoutes.communities.path),
              style: TextButton.styleFrom(foregroundColor: green, minimumSize: const Size(48, 48)),
              child: Text(l10n.habits_empty_catalog),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing is due today: other habits are paused, weekly, or on other days.
class _NothingToday extends StatelessWidget {
  final int pausedCount;

  const _NothingToday({required this.pausedCount});

  @override
  Widget build(BuildContext context) {
    final theme = context.themeOf;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const ExcludeSemantics(child: Text('☕', style: TextStyle(fontSize: 24))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pausedCount > 0 ? context.l10n.habits_nothing_today(pausedCount) : context.l10n.habits_today_nothing,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholders shaped like the content, so nothing jumps when habits arrive.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final color = context.themeOf.cardColor;
    Widget block(double height) => Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        );
    return Semantics(
      label: context.l10n.habits_loading,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [block(88), const SizedBox(height: 44), block(76), block(76), block(76)],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(l10n.habits_error_load, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: Text(l10n.communities_retry)),
          ],
        ),
      ),
    );
  }
}
