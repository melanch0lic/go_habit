import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_section.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/weekly_consistency.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/domain/streak.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/view/components/user_avatar.dart';
import 'package:go_habit/feature/social/view/social_texts.dart';
import 'package:go_router/go_router.dart';

/// The top of the own profile screen: public identity with the edit action, the
/// user's statistics, and friends and privacy.
class MyProfileSection extends StatelessWidget {
  /// The private account email, shown to the owner only.
  final String? email;

  const MyProfileSection({this.email, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = context.select<MyProfileBloc, MyProfile?>((bloc) => bloc.state.profile);
    final incoming = context.select<FriendsBloc, int>((bloc) => bloc.state.incomingCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(email: email),
        const SizedBox(height: AppSpacing.section),
        AppSection(title: l10n.profile_section_stats, children: const [_OwnStats()]),
        const SizedBox(height: AppSpacing.section),
        AppSection(
          title: l10n.profile_section_social,
          children: [
            AppSettingsTile(
              icon: Icons.group_outlined,
              title: l10n.social_friends_title,
              subtitle: incoming > 0 ? l10n.social_incoming_count(incoming) : null,
              badgeCount: incoming,
              onTap: () => context.push(ProfileRoutes.friends.path),
            ),
            AppSettingsTile(
              icon: Icons.lock_outline,
              title: l10n.social_privacy_title,
              onTap: () => context.push(ProfileRoutes.privacy.path),
            ),
            if (profile != null)
              AppSettingsTile(
                icon: Icons.badge_outlined,
                title: l10n.social_view_public_profile,
                onTap: () => context.push(SocialRoutes.userOf(profile.publicId)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Avatar, nickname and bio, with editing as the primary action. Without a nickname
/// the primary action is choosing one.
class _Header extends StatelessWidget {
  final String? email;

  const _Header({required this.email});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final state = context.watch<MyProfileBloc>().state;
    final profile = state.profile;
    final email = this.email;

    final Widget identity;
    if (profile == null && state.status == MyProfileStatus.failure) {
      identity = Text(state.failure?.message(l10n) ?? '', style: theme.textTheme.bodyMedium);
    } else if (profile == null) {
      identity = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else {
      final bio = profile.bio?.trim();
      identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.nickname == null ? l10n.social_no_nickname : '@${profile.nickname}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(bio, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            UserAvatar(nickname: profile?.nickname, avatar: profile?.avatar, size: 72),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: identity),
          ],
        ),
        if (email != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: '$email. ${l10n.profile_email_hint}',
            excludeSemantics: true,
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: AppSizes.iconSm, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                // The account email is private: shown here only, never to other users.
                Expanded(
                  child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],
        if (profile != null) ...[
          const SizedBox(height: AppSpacing.lg),
          if (profile.nickname == null)
            FilledButton.icon(
              onPressed: () => context.push(ProfileRoutes.edit.path),
              icon: const Icon(Icons.alternate_email),
              label: Text(l10n.social_set_nickname),
            )
          else
            OutlinedButton.icon(
              onPressed: () => context.push(ProfileRoutes.edit.path),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.social_edit_profile),
            ),
        ],
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
    final green = theme.colorScheme.primary;
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
          child: Semantics(
            label: '$value, $label',
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: green),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
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
    );
  }
}
