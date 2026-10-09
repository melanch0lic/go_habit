import 'dart:async';

import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/nickname_rules.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

class _Account {
  final String id;
  final String publicId;
  String? nickname;
  String? bio;
  String? avatar;
  ProfileVisibility stats = ProfileVisibility.friends;
  ProfileVisibility communities = ProfileVisibility.friends;
  int weekCompleted;
  int weekEligible;
  List<String> memberOf;

  _Account(this.id, {this.weekCompleted = 0, this.weekEligible = 0, this.memberOf = const []}) : publicId = 'pub-$id';
}

class _Pair {
  final String requester;
  bool accepted = false;
  DateTime since;

  _Pair(this.requester, this.since);
}

/// An in-memory stand-in for the Supabase functions, with the same rules: one row per
/// pair, crossing requests become a friendship, blocks hide the blocker, privacy
/// settings decide what others see.
class FakeSocialServer {
  final _accounts = <String, _Account>{};
  final _pairs = <String, _Pair>{};
  final _blocks = <(String, String)>{};
  DateTime now = DateTime.utc(2026, 10, 9, 12);

  void addUser(String id,
      {String? nickname, int weekCompleted = 0, int weekEligible = 0, List<String> memberOf = const []}) {
    _accounts[id] = _Account(id, weekCompleted: weekCompleted, weekEligible: weekEligible, memberOf: memberOf)
      ..nickname = nickname;
  }

  String publicIdOf(String id) => _accounts[id]!.publicId;

  static String _key(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  bool _blocked(String blocker, String blocked) => _blocks.contains((blocker, blocked));

  bool areFriends(String a, String b) => _pairs[_key(a, b)]?.accepted ?? false;

  int get pairCount => _pairs.length;

  bool _canSee(String viewer, _Account owner, ProfileVisibility visibility) =>
      viewer == owner.id ||
      (!_blocked(owner.id, viewer) &&
          !_blocked(viewer, owner.id) &&
          (visibility == ProfileVisibility.everyone ||
              (visibility == ProfileVisibility.friends && areFriends(viewer, owner.id))));

  Relationship _relationship(String viewer, String other) {
    if (viewer == other) return Relationship.self;
    if (_blocked(viewer, other)) return Relationship.blocked;
    final pair = _pairs[_key(viewer, other)];
    if (pair == null) return Relationship.none;
    if (pair.accepted) return Relationship.friends;
    return pair.requester == viewer ? Relationship.outgoing : Relationship.incoming;
  }

  _Account _resolve(String viewer, String publicId) {
    final target = _accounts.values.where((a) => a.publicId == publicId).firstOrNull;
    if (target == null || _blocked(target.id, viewer)) throw const SocialException(SocialFailure.notFound);
    return target;
  }

  MyProfile profileOf(String id) {
    final a = _accounts[id]!;
    return MyProfile(
      publicId: a.publicId,
      nickname: a.nickname,
      bio: a.bio,
      avatar: a.avatar,
      statsVisibility: a.stats,
      communitiesVisibility: a.communities,
    );
  }

  MyProfile updateProfile(String id, {required String nickname, String? bio, String? avatar}) {
    if (NicknameRules.validate(nickname) != null) throw const SocialException(SocialFailure.nicknameInvalid);
    final taken =
        _accounts.values.any((a) => a.id != id && a.nickname != null && NicknameRules.same(a.nickname!, nickname));
    if (taken) throw const SocialException(SocialFailure.nicknameTaken);
    _accounts[id]!
      ..nickname = nickname
      ..bio = bio
      ..avatar = avatar;
    return profileOf(id);
  }

  MyProfile updatePrivacy(String id, ProfileVisibility stats, ProfileVisibility communities) {
    _accounts[id]!
      ..stats = stats
      ..communities = communities;
    return profileOf(id);
  }

  NicknameStatus nicknameStatus(String id, String nickname) {
    if (NicknameRules.validate(nickname) != null) return NicknameStatus.invalid;
    final taken =
        _accounts.values.any((a) => a.id != id && a.nickname != null && NicknameRules.same(a.nickname!, nickname));
    return taken ? NicknameStatus.taken : NicknameStatus.available;
  }

  List<UserSearchResult> search(String viewer, String query) => [
        for (final a in _accounts.values)
          if (a.nickname != null && NicknameRules.same(a.nickname!, query) && !_blocked(a.id, viewer))
            UserSearchResult(
              user: PublicUser(publicId: a.publicId, nickname: a.nickname, avatar: a.avatar),
              relationship: _relationship(viewer, a.id),
            ),
      ];

  PublicProfile publicProfile(String viewer, String publicId) {
    final owner = _resolve(viewer, publicId);
    final stats = _canSee(viewer, owner, owner.stats);
    final communities = _canSee(viewer, owner, owner.communities);
    final mine = _accounts[viewer]!.memberOf;
    return PublicProfile(
      user: PublicUser(publicId: owner.publicId, nickname: owner.nickname, avatar: owner.avatar),
      bio: owner.bio,
      relationship: _relationship(viewer, owner.id),
      statsVisible: stats,
      activeHabits: stats ? 1 : null,
      weekCompletedDays: stats ? owner.weekCompleted : null,
      weekEligibleDays: stats ? owner.weekEligible : null,
      friendsCount:
          stats ? _pairs.entries.where((e) => e.value.accepted && e.key.split('|').contains(owner.id)).length : null,
      communitiesVisible: communities,
      communities: communities
          ? [
              for (final c in owner.memberOf)
                if (owner.id == viewer || mine.contains(c)) c
            ]
          : null,
    );
  }

  Relationship act(String caller, String action, String publicId) {
    if (action == 'block' || action == 'unblock') {
      final target = _accounts.values.where((a) => a.publicId == publicId).firstOrNull;
      if (target == null) throw const SocialException(SocialFailure.notFound);
      if (action == 'block') {
        _blocks.add((caller, target.id));
        _pairs.remove(_key(caller, target.id));
        return Relationship.blocked;
      }
      _blocks.remove((caller, target.id));
      return _relationship(caller, target.id);
    }
    final target = _resolve(caller, publicId);
    final key = _key(caller, target.id);
    final pair = _pairs[key];
    switch (action) {
      case 'send':
        if (target.id == caller) throw const SocialException(SocialFailure.notAllowed);
        if (_blocked(caller, target.id)) throw const SocialException(SocialFailure.blockedByMe);
        if (pair == null) {
          _pairs[key] = _Pair(caller, now);
          return Relationship.outgoing;
        }
        if (!pair.accepted && pair.requester != caller) {
          pair
            ..accepted = true
            ..since = now;
        }
        return _relationship(caller, target.id);
      case 'accept' || 'reject':
        if (pair != null && pair.accepted) return Relationship.friends;
        if (pair == null || pair.requester != target.id) throw const SocialException(SocialFailure.notFound);
        if (action == 'accept') {
          pair
            ..accepted = true
            ..since = now;
          return Relationship.friends;
        }
        _pairs.remove(key);
        return Relationship.none;
      case 'cancel':
        if (pair != null && !pair.accepted && pair.requester == caller) _pairs.remove(key);
        return _relationship(caller, target.id);
      case 'remove':
        if (pair != null && pair.accepted) _pairs.remove(key);
        return _relationship(caller, target.id);
    }
    throw StateError(action);
  }

  List<SocialConnection> graph(String caller) {
    final result = <SocialConnection>[];
    for (final MapEntry(:key, value: pair) in _pairs.entries) {
      final ids = key.split('|');
      if (!ids.contains(caller)) continue;
      final other = _accounts[ids.firstWhere((id) => id != caller)]!;
      result.add(SocialConnection(
        user: PublicUser(publicId: other.publicId, nickname: other.nickname, avatar: other.avatar),
        kind: pair.accepted
            ? ConnectionKind.friend
            : pair.requester == caller
                ? ConnectionKind.outgoing
                : ConnectionKind.incoming,
        since: pair.since,
        requestedByMe: pair.requester == caller,
      ));
    }
    for (final (blocker, blocked) in _blocks) {
      if (blocker != caller) continue;
      final other = _accounts[blocked]!;
      result.add(SocialConnection(
        user: PublicUser(publicId: other.publicId, nickname: other.nickname, avatar: other.avatar),
        kind: ConnectionKind.blocked,
        since: now,
      ));
    }
    return result;
  }

  /// Same rule as `friends_leaderboard`: consistency desc, completed desc, nickname.
  CommunityLeaderboard friendsLeaderboard(String caller) {
    final people = [
      _accounts[caller]!,
      for (final a in _accounts.values)
        if (a.id != caller && areFriends(caller, a.id) && _canSee(caller, a, a.stats)) a,
    ];
    final ranked = people.where((a) => a.weekEligible > 0).toList()
      ..sort((a, b) {
        final byConsistency = (b.weekCompleted / b.weekEligible).compareTo(a.weekCompleted / a.weekEligible);
        if (byConsistency != 0) return byConsistency;
        final byDays = b.weekCompleted.compareTo(a.weekCompleted);
        if (byDays != 0) return byDays;
        return (a.nickname ?? '').toLowerCase().compareTo((b.nickname ?? '').toLowerCase());
      });
    return CommunityLeaderboard.fromRows([
      for (final (index, a) in ranked.indexed)
        LeaderboardEntry(
          rank: index + 1,
          displayName: a.nickname,
          publicId: a.publicId,
          avatar: a.avatar,
          isMe: a.id == caller,
          completedDays: a.weekCompleted,
          eligibleDays: a.weekEligible,
          consistency: a.weekCompleted * 100 / a.weekEligible,
          rankedCount: ranked.length,
        ),
    ]);
  }
}

/// One signed-in user's session against [FakeSocialServer].
class FakeSocialRepository implements SocialRepository {
  final FakeSocialServer server;
  final String userId;
  final log = <String>[];
  final _changes = StreamController<void>.broadcast();

  bool online = true;

  /// Thrown by the next calls of the named operations.
  final failures = <String, SocialFailure>{};

  /// Operations wait for this completer, if set.
  Completer<void>? gate;

  FakeSocialRepository(this.server, this.userId);

  Future<T> _call<T>(String name, T Function() body, {bool needsConnection = true}) async {
    log.add(name);
    await gate?.future;
    if (needsConnection && !online) throw const SocialException(SocialFailure.offline);
    final failure = failures[name.split(':').first];
    if (failure != null) throw SocialException(failure);
    return body();
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MyProfile> loadMyProfile() => _call('profile', () => server.profileOf(userId));

  @override
  Future<MyProfile> updateProfile({required String nickname, String? bio, String? avatar}) => _call(
      'update:$nickname', () => server.updateProfile(userId, nickname: nickname.trim(), bio: bio, avatar: avatar));

  @override
  Future<MyProfile> updatePrivacy({required ProfileVisibility stats, required ProfileVisibility communities}) =>
      _call('privacy', () => server.updatePrivacy(userId, stats, communities));

  @override
  Future<NicknameStatus> nicknameStatus(String nickname) =>
      _call('status:$nickname', () => server.nicknameStatus(userId, nickname));

  @override
  Future<List<UserSearchResult>> search(String nickname) =>
      _call('search:$nickname', () => server.search(userId, nickname));

  @override
  Future<PublicProfile> publicProfile(String publicId) =>
      _call('publicProfile', () => server.publicProfile(userId, publicId));

  Future<Relationship> _act(String action, String publicId) async {
    final result = await _call('$action:$publicId', () => server.act(userId, action, publicId));
    _changes.add(null);
    return result;
  }

  @override
  Future<Relationship> sendRequest(String publicId) => _act('send', publicId);

  @override
  Future<Relationship> respondToRequest(String publicId, {required bool accept}) =>
      _act(accept ? 'accept' : 'reject', publicId);

  @override
  Future<Relationship> cancelRequest(String publicId) => _act('cancel', publicId);

  @override
  Future<Relationship> removeFriend(String publicId) => _act('remove', publicId);

  @override
  Future<Relationship> block(String publicId) => _act('block', publicId);

  @override
  Future<Relationship> unblock(String publicId) => _act('unblock', publicId);

  @override
  Future<SocialGraph> loadGraph() => _call('graph', () => SocialGraph(connections: server.graph(userId)));

  @override
  Future<CommunityLeaderboard> friendsLeaderboard() => _call('leaderboard', () => server.friendsLeaderboard(userId));

  Future<void> dispose() => _changes.close();
}
