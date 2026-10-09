import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/communities/view/components/leaderboard_section.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:go_habit/feature/social/bloc/friends_bloc.dart';
import 'package:go_habit/feature/social/bloc/friends_leaderboard_bloc.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/domain/friend_action.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';
import 'package:go_habit/feature/social/view/components/relationship_actions.dart';
import 'package:go_habit/feature/social/view/components/user_avatar.dart';
import 'package:go_habit/feature/social/view/social_texts.dart';
import 'package:go_router/go_router.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

/// Friends, requests (incoming, outgoing, blocked) and the friends ranking.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) => ScopeBuilder<AppScopeContainer>.withPlaceholder(
        builder: (context, scope) => FriendsView(repository: scope.socialRepository.get),
      );
}

/// [FriendsScreen] with its dependency passed in (used by tests).
class FriendsView extends StatefulWidget {
  final SocialRepository repository;

  const FriendsView({required this.repository, super.key});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  @override
  void initState() {
    super.initState();
    // Fresh data whenever the section is opened.
    context.read<FriendsBloc>().add(const FriendsRequested());
  }

  void _onNotice(BuildContext context, FriendsState state) {
    final text = state.notice?.message(context.l10n);
    if (text == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final green = context.theme.commonColors.green100;
    final incoming = context.select<FriendsBloc, int>((bloc) => bloc.state.incomingCount);

    return BlocListener<FriendsBloc, FriendsState>(
      listenWhen: (previous, current) => current.notice != null,
      listener: _onNotice,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.social_friends_title),
            bottom: TabBar(
              indicatorColor: green,
              labelColor: green,
              tabs: [
                Tab(text: l10n.social_tab_friends),
                Tab(
                  child: Badge(
                    isLabelVisible: incoming > 0,
                    label: Text('$incoming'),
                    child: Text(l10n.social_tab_requests),
                  ),
                ),
                Tab(text: l10n.social_tab_ranking),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const _FriendsTab(),
              const _RequestsTab(),
              BlocProvider(
                create: (_) => FriendsLeaderboardBloc(widget.repository)..add(const FriendsLeaderboardRequested()),
                child: const _RankingTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openProfile(BuildContext context, PublicUser user) => context.push(SocialRoutes.userOf(user.publicId));

Future<void> _reload(BuildContext context) {
  final bloc = context.read<FriendsBloc>()..add(const FriendsRequested());
  return bloc.stream.firstWhere((state) => state.status != LoadState.loading);
}

EdgeInsets _listPadding(BuildContext context) =>
    EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom);

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final needsNickname = context.select<MyProfileBloc, bool>((bloc) => bloc.state.needsNickname);

    return BlocBuilder<FriendsBloc, FriendsState>(
      builder: (context, state) {
        final friends = state.graph.friends;
        return RefreshIndicator(
          onRefresh: () => _reload(context),
          child: ListView(
            padding: _listPadding(context),
            children: [
              if (needsNickname) const _NicknameCallout(),
              const _SearchSection(),
              const SizedBox(height: 20),
              _SectionTitle(l10n.social_friends_count(friends.length)),
              if (state.graph.isOffline) _InfoBanner(icon: Icons.cloud_off_outlined, text: l10n.social_offline_banner),
              ..._statusOr(
                context,
                state,
                friends.isEmpty
                    ? [_Empty(icon: Icons.group_outlined, text: l10n.social_no_friends)]
                    : [
                        for (final friend in friends)
                          _UserTile(user: friend.user, onTap: () => _openProfile(context, friend.user))
                      ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The list content, or loading / error placeholders before the first load.
List<Widget> _statusOr(BuildContext context, FriendsState state, List<Widget> content) {
  final l10n = context.l10n;
  if (state.status == LoadState.ready || state.graph.connections.isNotEmpty) return content;
  if (state.status == LoadState.failure) {
    return [
      _Empty(
        icon: Icons.error_outline,
        text: (state.failure ?? SocialFailure.unknown).message(l10n),
        actionLabel: l10n.communities_retry,
        onAction: () => context.read<FriendsBloc>().add(const FriendsRequested()),
      ),
    ];
  }
  return const [Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator.adaptive()))];
}

class _NicknameCallout extends StatelessWidget {
  const _NicknameCallout();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.alternate_email),
        title: Text(l10n.social_nickname_callout),
        trailing: TextButton(
          onPressed: () => context.push(ProfileRoutes.edit.path),
          child: Text(l10n.social_set_nickname),
        ),
      ),
    );
  }
}

class _SearchSection extends StatefulWidget {
  const _SearchSection();

  @override
  State<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<_SearchSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<FriendsBloc>().add(FriendSearchSubmitted(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final search = context.select<FriendsBloc, FriendSearchState>((bloc) => bloc.state.search);
    final busy = context.select<FriendsBloc, Set<String>>((bloc) => bloc.state.busy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.social_search_label,
            hintText: l10n.social_search_hint,
            prefixText: '@',
            border: const OutlineInputBorder(),
            suffixIcon:
                IconButton(tooltip: l10n.social_search_label, icon: const Icon(Icons.search), onPressed: _submit),
          ),
        ),
        const SizedBox(height: 8),
        switch (search.status) {
          LoadState.initial => const SizedBox.shrink(),
          LoadState.loading => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          LoadState.failure => _InfoBanner(
              icon: Icons.error_outline,
              text: (search.failure ?? SocialFailure.unknown).message(l10n),
            ),
          LoadState.ready when search.results.isEmpty =>
            _InfoBanner(icon: Icons.person_search_outlined, text: l10n.social_search_empty(search.query)),
          LoadState.ready => Column(
              children: [
                for (final result in search.results)
                  _UserTile(
                    user: result.user,
                    subtitle: result.relationship == Relationship.self ? l10n.social_this_is_you : null,
                    onTap: () => _openProfile(context, result.user),
                    trailing: RelationshipActions(
                      relationship: result.relationship,
                      busy: busy.contains(result.user.publicId),
                      onAction: (action) =>
                          context.read<FriendsBloc>().add(FriendActionRequested(action, result.user.publicId)),
                    ),
                  ),
              ],
            ),
        },
      ],
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<FriendsBloc, FriendsState>(
      builder: (context, state) {
        final graph = state.graph;
        final accepted = graph.recentlyAccepted(DateTime.now());
        final empty = graph.incoming.isEmpty && graph.outgoing.isEmpty && graph.blocked.isEmpty && accepted.isEmpty;

        void act(FriendAction action, PublicUser user) =>
            context.read<FriendsBloc>().add(FriendActionRequested(action, user.publicId));

        Widget actions(Relationship relationship, PublicUser user) => RelationshipActions(
              relationship: relationship,
              busy: state.busy.contains(user.publicId),
              onAction: (action) => act(action, user),
            );

        return RefreshIndicator(
          onRefresh: () => _reload(context),
          child: ListView(
            padding: _listPadding(context),
            children: [
              if (graph.isOffline) _InfoBanner(icon: Icons.cloud_off_outlined, text: l10n.social_offline_banner),
              ..._statusOr(context, state, [
                if (empty) _Empty(icon: Icons.mark_email_read_outlined, text: l10n.social_no_requests),
                for (final connection in accepted)
                  _InfoBanner(
                    icon: Icons.celebration_outlined,
                    text: l10n.social_request_accepted_notice(displayHandle(connection.user.nickname, l10n)),
                  ),
                if (graph.incoming.isNotEmpty) ...[
                  _SectionTitle(l10n.social_incoming),
                  for (final request in graph.incoming)
                    _UserTile(
                      user: request.user,
                      onTap: () => _openProfile(context, request.user),
                      bottom: actions(Relationship.incoming, request.user),
                    ),
                ],
                if (graph.outgoing.isNotEmpty) ...[
                  _SectionTitle(l10n.social_outgoing),
                  for (final request in graph.outgoing)
                    _UserTile(
                      user: request.user,
                      subtitle: l10n.social_waiting,
                      onTap: () => _openProfile(context, request.user),
                      trailing: actions(Relationship.outgoing, request.user),
                    ),
                ],
                if (graph.blocked.isNotEmpty) ...[
                  _SectionTitle(l10n.social_blocked),
                  for (final blocked in graph.blocked)
                    _UserTile(user: blocked.user, trailing: actions(Relationship.blocked, blocked.user)),
                ],
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _RankingTab extends StatelessWidget {
  const _RankingTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    return BlocBuilder<FriendsLeaderboardBloc, FriendsLeaderboardState>(
      builder: (context, state) {
        final leaderboard = state.leaderboard;
        final me = leaderboard?.me;
        return RefreshIndicator(
          onRefresh: () {
            final bloc = context.read<FriendsLeaderboardBloc>()..add(const FriendsLeaderboardRequested());
            return bloc.stream.firstWhere((s) => s.status != LeaderboardLoad.loading);
          },
          child: ListView(
            padding: _listPadding(context),
            children: [
              Text(l10n.social_ranking_rules, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
              const SizedBox(height: 12),
              if (me != null && me.rank != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.community_my_rank(me.rank!, leaderboard!.rankedCount),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              if (leaderboard == null && state.status == LeaderboardLoad.failure)
                _Empty(
                  icon: Icons.error_outline,
                  text: (state.failure ?? SocialFailure.unknown).message(l10n),
                  actionLabel: l10n.communities_retry,
                  onAction: () => context.read<FriendsLeaderboardBloc>().add(const FriendsLeaderboardRequested()),
                )
              else if (leaderboard == null)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator.adaptive()))
              else if (leaderboard.entries.length <= 1)
                _Empty(icon: Icons.leaderboard_outlined, text: l10n.social_ranking_empty)
              else
                for (final entry in leaderboard.entries) LeaderboardRow(entry: entry),
            ],
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final PublicUser user;
  final String? subtitle;
  final Widget? trailing;

  /// Actions under the name (for requests that need two buttons).
  final Widget? bottom;
  final VoidCallback? onTap;

  const _UserTile({required this.user, this.subtitle, this.trailing, this.bottom, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(nickname: user.nickname, avatar: user.avatar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayHandle(user.nickname, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), Flexible(child: trailing!)],
                ],
              ),
              if (bottom != null) ...[const SizedBox(height: 8), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Semantics(
          header: true,
          child: Text(text, style: context.themeOf.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
      );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.theme.commonColors.green100.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: context.themeOf.textTheme.bodyMedium)),
            ],
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Empty({required this.icon, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: context.themeOf.textTheme.bodySmall?.color),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: context.themeOf.textTheme.bodyLarge),
            if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}
