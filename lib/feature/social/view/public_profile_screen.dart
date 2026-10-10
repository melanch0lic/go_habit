import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/domain/repositories/community_repository.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:go_habit/feature/social/bloc/public_profile_bloc.dart';
import 'package:go_habit/feature/social/domain/friend_action.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';
import 'package:go_habit/feature/social/view/components/relationship_actions.dart';
import 'package:go_habit/feature/social/view/components/user_avatar.dart';
import 'package:go_habit/feature/social/view/social_texts.dart';
import 'package:go_router/go_router.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

/// A user's public profile: only what the owner's privacy settings allow.
class PublicProfileScreen extends StatelessWidget {
  final String publicId;

  const PublicProfileScreen({required this.publicId, super.key});

  @override
  Widget build(BuildContext context) => ScopeBuilder<AppScopeContainer>.withPlaceholder(
        builder: (context, scope) => PublicProfileView(
          publicId: publicId,
          repository: scope.socialRepository.get,
          communities: scope.communityRepository.get,
        ),
      );
}

/// [PublicProfileScreen] with its dependencies passed in (used by tests).
class PublicProfileView extends StatelessWidget {
  final String publicId;
  final SocialRepository repository;
  final CommunityRepository communities;

  const PublicProfileView({required this.publicId, required this.repository, required this.communities, super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PublicProfileBloc(repository, publicId: publicId)..add(const PublicProfileRequested()),
        child: _ProfileBody(communities: communities),
      );
}

class _ProfileBody extends StatelessWidget {
  final CommunityRepository communities;

  const _ProfileBody({required this.communities});

  Future<void> _confirm(BuildContext context, FriendAction action) async {
    final bloc = context.read<PublicProfileBloc>();
    final l10n = context.l10n;
    final (title, message, confirm) = switch (action) {
      FriendAction.block => (l10n.social_block_title, l10n.social_block_message, l10n.social_block),
      FriendAction.remove => (l10n.social_remove_title, l10n.social_remove_message, l10n.social_remove_friend),
      _ => (null, null, null),
    };
    if (title == null) {
      bloc.add(PublicProfileActionRequested(action));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.themeOf.cardColor,
        title: Text(title),
        content: Text(message!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(confirm!),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(PublicProfileActionRequested(action));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<PublicProfileBloc, PublicProfileState>(
      listenWhen: (previous, current) => current.notice != null,
      listener: (context, state) {
        final text = state.notice?.message(l10n);
        if (text != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(text)));
        }
      },
      builder: (context, state) {
        final profile = state.profile;
        final relationship = profile?.relationship;
        return Scaffold(
          appBar: AppBar(
            title: Text(profile == null ? l10n.social_profile_title : displayHandle(profile.user.nickname, l10n)),
            actions: [
              if (relationship != null && relationship != Relationship.self && !state.isBusy)
                PopupMenuButton<FriendAction>(
                  tooltip: l10n.social_more_actions,
                  onSelected: (action) => _confirm(context, action),
                  itemBuilder: (context) => [
                    if (relationship == Relationship.blocked)
                      PopupMenuItem(value: FriendAction.unblock, child: Text(l10n.social_unblock))
                    else
                      PopupMenuItem(value: FriendAction.block, child: Text(l10n.social_block)),
                  ],
                ),
            ],
          ),
          body: switch (profile) {
            null when state.status == PublicProfileStatus.failure => _Message(
                text: (state.failure ?? SocialFailure.unknown).message(l10n),
                onRetry: state.failure == SocialFailure.notFound
                    ? null
                    : () => context.read<PublicProfileBloc>().add(const PublicProfileRequested()),
              ),
            null => const Center(child: CircularProgressIndicator.adaptive()),
            final profile => RefreshIndicator(
                onRefresh: () {
                  final bloc = context.read<PublicProfileBloc>()..add(const PublicProfileRequested());
                  return bloc.stream.firstWhere((s) => s.status != PublicProfileStatus.loading);
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    _Header(profile: profile),
                    const SizedBox(height: 16),
                    if (profile.relationship == Relationship.self)
                      OutlinedButton.icon(
                        onPressed: () => context.push(ProfileRoutes.edit.path),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.social_edit_profile),
                      )
                    else
                      Center(
                        child: RelationshipActions(
                          relationship: profile.relationship,
                          busy: state.isBusy,
                          expanded: true,
                          onAction: (action) => _confirm(context, action),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _Stats(profile: profile),
                    const SizedBox(height: 16),
                    _SharedCommunities(profile: profile, repository: communities),
                  ],
                ),
              ),
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final PublicProfile profile;

  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final bio = profile.bio;
    return Column(
      children: [
        UserAvatar(nickname: profile.user.nickname, avatar: profile.user.avatar, size: 96),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            displayHandle(profile.user.nickname, l10n),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (profile.relationship == Relationship.friends)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.social_friends_badge, style: TextStyle(color: context.theme.commonColors.green100)),
          ),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(bio, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  final PublicProfile profile;

  const _Stats({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    if (!profile.statsVisible) {
      return _Card(
          child: Row(children: [
        const Icon(Icons.lock_outline),
        const SizedBox(width: 12),
        Expanded(child: Text(l10n.social_stats_hidden, style: theme.textTheme.bodyMedium)),
      ]));
    }
    final consistency = profile.weekConsistency;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.social_stats_title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Stat(value: '${profile.activeHabits ?? 0}', label: l10n.social_stat_active_habits),
              _Stat(
                value: consistency == null ? '—' : '${consistency.round()}%',
                label: l10n.social_stat_week(profile.weekCompletedDays ?? 0, profile.weekEligibleDays ?? 0),
              ),
              _Stat(value: '${profile.friendsCount ?? 0}', label: l10n.social_stat_friends),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = context.themeOf;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: context.theme.commonColors.green100)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SharedCommunities extends StatefulWidget {
  final PublicProfile profile;
  final CommunityRepository repository;

  const _SharedCommunities({required this.profile, required this.repository});

  @override
  State<_SharedCommunities> createState() => _SharedCommunitiesState();
}

class _SharedCommunitiesState extends State<_SharedCommunities> {
  Future<List<HabitTemplate>>? _templates;
  List<String>? _ids;

  /// Templates come from the catalog cache; loaded once per list of ids.
  Future<List<HabitTemplate>> _load(List<String> ids) {
    if (_templates == null || !listEquals(ids, _ids)) {
      _ids = ids;
      _templates = Future.wait(ids.map(widget.repository.getTemplate))
          .then((list) => list.nonNulls.toList())
          .catchError((Object _) => <HabitTemplate>[]);
    }
    return _templates!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final profile = widget.profile;
    final ids = profile.communities;
    final own = profile.relationship == Relationship.self;
    if (!profile.communitiesVisible || ids == null) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            own ? l10n.social_my_communities : l10n.social_shared_communities,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (ids.isEmpty)
            Text(own ? l10n.communities_empty_mine : l10n.social_no_shared_communities,
                style: theme.textTheme.bodyMedium)
          else
            FutureBuilder<List<HabitTemplate>>(
              future: _load(ids),
              builder: (context, snapshot) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in snapshot.data ?? const <HabitTemplate>[])
                    ActionChip(
                      avatar: Text(template.icon),
                      label: Text(template.titleFor(languageCodeOf(context))),
                      onPressed: () => context.go(CommunityRoutes.detailOf(template.id)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

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
      child: child,
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (onRetry != null) TextButton(onPressed: onRetry, child: Text(context.l10n.communities_retry)),
            ],
          ),
        ),
      );
}
