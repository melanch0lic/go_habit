import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/bloc/community_detail_bloc.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/social/view/components/user_avatar.dart';
import 'package:go_router/go_router.dart';

/// The ranking of the last finished week with its period, the caller's place or the
/// reason they are not ranked, and the loading, empty, offline and error states.
class LeaderboardSection extends StatelessWidget {
  final CommunityDetailState state;
  final VoidCallback onRetry;

  const LeaderboardSection({required this.state, required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final leaderboard = state.leaderboard;
    final me = leaderboard?.me;
    final secondary = theme.textTheme.bodySmall;

    final Widget body;
    if (leaderboard == null && state.leaderboardStatus != LoadStatus.failure) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    } else if (leaderboard == null) {
      body = _Message(
        text: state.leaderboardFailure == CommunityFailure.offline
            ? l10n.community_leaderboard_offline
            : l10n.community_leaderboard_failed,
        onRetry: onRetry,
      );
    } else if (leaderboard.entries.isEmpty) {
      body = _Message(text: l10n.community_leaderboard_empty);
    } else {
      body = Column(children: [for (final entry in leaderboard.entries) LeaderboardRow(entry: entry)]);
    }

    final weekStart = leaderboard?.weekStart;
    final myStatus = me == null ? null : _myStatus(context, me, leaderboard!.rankedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.community_leaderboard_title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (state.leaderboardStatus == LoadStatus.loading && leaderboard != null)
              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        if (weekStart != null) ...[
          const SizedBox(height: 2),
          Text(l10n.community_leaderboard_period(weekRange(context, weekStart)), style: secondary),
        ],
        if (myStatus != null) ...[
          const SizedBox(height: 4),
          Text(myStatus, style: secondary),
        ],
        if (state.hasUnsyncedChanges) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 16, color: secondary?.color),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.community_unsynced_hint, style: secondary)),
            ],
          ),
        ],
        if (state.leaderboardStatus == LoadStatus.failure && leaderboard != null) ...[
          const SizedBox(height: 4),
          Text(state.leaderboardFailure?.message(l10n) ?? '', style: secondary),
        ],
        const SizedBox(height: 8),
        body,
      ],
    );
  }

  /// The caller's place, or why they are not ranked for the week.
  String _myStatus(BuildContext context, LeaderboardEntry me, int rankedCount) {
    final l10n = context.l10n;
    final rank = me.rank;
    if (rank != null) return l10n.community_my_rank(rank, rankedCount);
    return switch (me.status) {
      LeaderboardStatus.joinedRecently => l10n.community_not_ranked_yet,
      LeaderboardStatus.paused => l10n.community_status_paused,
      LeaderboardStatus.noScheduledActions => l10n.community_status_no_actions,
      LeaderboardStatus.noHabit || LeaderboardStatus.scored => l10n.community_not_ranked,
    };
  }
}

/// "5–11 окт." for the week starting [monday], in the app's locale.
String weekRange(BuildContext context, CalendarDay monday) {
  final material = MaterialLocalizations.of(context);
  return '${material.formatShortMonthDay(monday.toDateTime())} – '
      '${material.formatShortMonthDay(monday.addDays(6).toDateTime())}';
}

/// One ranked member: place, avatar, name (or a neutral label), completed and
/// expected actions, successful weeks in a row and the percentage. Opens the member's
/// public profile when their name is visible.
class LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;

  const LeaderboardRow({required this.entry, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final green = context.theme.commonColors.green100;
    final name = entry.isMe
        ? l10n.community_you
        : entry.displayName == null
            ? l10n.community_member_fallback
            : '@${entry.displayName}';
    final percent = l10n.community_percent(entry.displayPercent ?? 0);
    final details = [
      l10n.community_actions(entry.completed, entry.expected),
      if (entry.successWeeks > 0) l10n.community_success_weeks(entry.successWeeks),
    ].join(' · ');
    final publicId = entry.publicId;
    final canOpen = publicId != null && !entry.isMe;

    return Semantics(
      container: true,
      button: canOpen,
      label: [
        l10n.community_rank(entry.rank ?? 0),
        name,
        percent,
        l10n.community_actions_semantics(entry.completed, entry.expected),
        if (entry.successWeeks > 0) l10n.community_success_weeks(entry.successWeeks),
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: entry.isMe ? green.withValues(alpha: 0.14) : theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: entry.isMe ? green : theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canOpen ? () => context.push(SocialRoutes.userOf(publicId)) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('${entry.rank}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  UserAvatar(nickname: entry.displayName, avatar: entry.avatar, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: entry.isMe ? FontWeight.bold : null),
                        ),
                        Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(percent,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: green)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center, style: context.themeOf.textTheme.bodyMedium),
            if (onRetry != null) TextButton(onPressed: onRetry, child: Text(context.l10n.communities_retry)),
          ],
        ),
      );
}
