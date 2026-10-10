import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/weekly_consistency.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/domain/streak.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/view/components/user_avatar.dart';
import 'package:go_habit/feature/social/view/social_texts.dart';
import 'package:go_router/go_router.dart';

/// The top of the own profile screen: public identity, own statistics, friends and
/// privacy.
class MyProfileSection extends StatelessWidget {
  const MyProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final state = context.watch<MyProfileBloc>().state;
    final profile = state.profile;
    final incoming = context.select<FriendsBloc, int>((bloc) => bloc.state.incomingCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              UserAvatar(nickname: profile?.nickname, avatar: profile?.avatar, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile == null && state.status == MyProfileStatus.failure)
                      Text(state.failure?.message(l10n) ?? '', style: theme.textTheme.bodySmall)
                    else if (profile == null)
                      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (profile.nickname == null) ...[
                      Text(l10n.social_no_nickname, style: theme.textTheme.titleMedium),
                      TextButton(
                        onPressed: () => context.push(ProfileRoutes.edit.path),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 40)),
                        child: Text(l10n.social_set_nickname),
                      ),
                    ] else ...[
                      Text(
                        '@${profile.nickname}',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (profile.bio case final bio? when bio.isNotEmpty)
                        Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (profile != null)
                IconButton(
                  tooltip: l10n.social_edit_profile,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(ProfileRoutes.edit.path),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _OwnStats(),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Badge(
                  isLabelVisible: incoming > 0,
                  label: Text('$incoming'),
                  child: const Icon(Icons.group_outlined),
                ),
                title: Text(l10n.social_friends_title),
                subtitle: incoming > 0 ? Text(l10n.social_incoming_count(incoming)) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(ProfileRoutes.friends.path),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(l10n.social_privacy_title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(ProfileRoutes.privacy.path),
              ),
              if (profile != null)
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(l10n.social_view_public_profile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(SocialRoutes.userOf(profile.publicId)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The user's own progress, from the habits and completions on this device. The app
/// has no XP or achievements yet, so these are the progression metrics it has.
class _OwnStats extends StatelessWidget {
  const _OwnStats();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final green = context.theme.commonColors.green100;
    final active = context.watch<HabitsBloc>().state.habits.where((habit) => habit.isActive).toList();
    final stats = context.watch<HabitStatsBloc>().state;

    // Streaks of different schedules have different units; the longest one is shown
    // with its own unit.
    HabitStreak? bestStreak;
    var completed = 0;
    var eligible = 0;
    if (stats is HabitStatsLoaded) {
      for (final habit in active) {
        final streak = stats.streakOf(habit);
        if (streak.count > (bestStreak?.count ?? 0)) bestStreak = streak;
        final week = WeeklyConsistency.compute(
          today: stats.today,
          joinedOn: CalendarDay(2000, 1, 1),
          habitCreatedAt: habit.createdAt,
          completedDays: stats.completedDaysOf(habit.id),
          schedule: habit.schedule,
        );
        completed += week.completedDays;
        eligible += week.eligibleDays;
      }
    }

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: green)),
              Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ],
          ),
        );

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stat('${active.length}', l10n.social_stat_active_habits),
            stat(
              '${bestStreak?.count ?? 0}',
              switch (bestStreak?.unit) {
                null => l10n.social_stat_best_streak,
                StreakUnit.days => l10n.social_best_streak_days(bestStreak!.count),
                StreakUnit.weeks => l10n.social_best_streak_weeks(bestStreak!.count),
                StreakUnit.occurrences => l10n.social_best_streak_occurrences(bestStreak!.count),
              },
            ),
            stat(eligible == 0 ? '—' : '${(completed * 100 / eligible).round()}%',
                l10n.social_stat_week(completed, eligible)),
          ],
        ),
      ),
    );
  }
}
