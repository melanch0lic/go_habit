import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/communities/bloc/community_detail_bloc.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/social/view/components/user_avatar.dart';
import 'package:go_router/go_router.dart';

/// The weekly ranking with its loading, empty, offline and error states.
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
        if (me != null) ...[
          const SizedBox(height: 4),
          Text(
            me.rank != null
                ? l10n.community_my_rank(me.rank!, leaderboard!.rankedCount)
                : state.membership?.isRanked ?? false
                    ? l10n.community_not_ranked_yet
                    : l10n.community_not_ranked,
            style: secondary,
          ),
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
}

/// One ranked member: place, avatar, name (or a neutral label), days and percent.
/// Opens the member's public profile when their name is visible.
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
    final percent = entry.roundedPercent ?? 0;
    final days = l10n.community_days(entry.completedDays, entry.eligibleDays);
    final publicId = entry.publicId;
    final canOpen = publicId != null && !entry.isMe;

    return Semantics(
      container: true,
      button: canOpen,
      label: '${l10n.community_rank(entry.rank ?? 0)}, $name, $percent%, $days',
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
                        Text(days, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('$percent%',
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
