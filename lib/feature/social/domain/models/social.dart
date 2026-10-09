import 'package:flutter/foundation.dart';

/// Who may see a part of the profile.
enum ProfileVisibility {
  everyone,
  friends,
  nobody;

  static ProfileVisibility parse(Object? value) =>
      ProfileVisibility.values.where((v) => v.name == value).firstOrNull ?? ProfileVisibility.friends;
}

/// The signed-in user's own profile. Only public fields and privacy settings; the
/// identity stays the auth user id, which is never shown to other users.
@immutable
class MyProfile {
  /// Opaque handle other users see instead of the auth id.
  final String publicId;
  final String? nickname;
  final String? bio;
  final String? avatar;

  /// Who sees the profile statistics and the user's name in community rankings.
  final ProfileVisibility statsVisibility;

  /// Who sees which communities the user belongs to.
  final ProfileVisibility communitiesVisibility;

  const MyProfile({
    required this.publicId,
    this.nickname,
    this.bio,
    this.avatar,
    this.statsVisibility = ProfileVisibility.friends,
    this.communitiesVisibility = ProfileVisibility.friends,
  });

  static const columns = 'public_id, nickname, bio, avatar, stats_visibility, communities_visibility';

  bool get hasNickname => nickname != null;

  factory MyProfile.fromJson(Map<String, dynamic> json) => MyProfile(
        publicId: json['public_id'] as String,
        nickname: json['nickname'] as String?,
        bio: json['bio'] as String?,
        avatar: json['avatar'] as String?,
        statsVisibility: ProfileVisibility.parse(json['stats_visibility']),
        communitiesVisibility: ProfileVisibility.parse(json['communities_visibility']),
      );

  Map<String, dynamic> toJson() => {
        'public_id': publicId,
        'nickname': nickname,
        'bio': bio,
        'avatar': avatar,
        'stats_visibility': statsVisibility.name,
        'communities_visibility': communitiesVisibility.name,
      };

  @override
  bool operator ==(Object other) =>
      other is MyProfile &&
      other.publicId == publicId &&
      other.nickname == nickname &&
      other.bio == bio &&
      other.avatar == avatar &&
      other.statsVisibility == statsVisibility &&
      other.communitiesVisibility == communitiesVisibility;

  @override
  int get hashCode => Object.hash(publicId, nickname, bio, avatar, statsVisibility, communitiesVisibility);
}

/// How the signed-in user relates to another user, as decided by the server.
enum Relationship {
  self,
  none,

  /// The signed-in user sent a request that is still pending.
  outgoing,

  /// The other user sent a request the signed-in user can accept or reject.
  incoming,
  friends,

  /// The signed-in user blocked the other user.
  blocked;

  static Relationship parse(Object? value) =>
      Relationship.values.where((r) => r.name == value).firstOrNull ?? Relationship.none;
}

/// The minimum public information about another user.
@immutable
class PublicUser {
  final String publicId;

  /// Null for users who have not chosen a nickname yet.
  final String? nickname;
  final String? avatar;

  const PublicUser({required this.publicId, this.nickname, this.avatar});

  factory PublicUser.fromJson(Map<String, dynamic> json) => PublicUser(
        publicId: json['public_id'] as String,
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
      );

  Map<String, dynamic> toJson() => {'public_id': publicId, 'nickname': nickname, 'avatar': avatar};

  @override
  bool operator ==(Object other) =>
      other is PublicUser && other.publicId == publicId && other.nickname == nickname && other.avatar == avatar;

  @override
  int get hashCode => Object.hash(publicId, nickname, avatar);
}

/// A search hit.
@immutable
class UserSearchResult {
  final PublicUser user;
  final Relationship relationship;

  const UserSearchResult({required this.user, required this.relationship});

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      UserSearchResult(user: PublicUser.fromJson(json), relationship: Relationship.parse(json['relationship']));
}

enum ConnectionKind {
  friend,
  incoming,
  outgoing,
  blocked;

  static ConnectionKind parse(Object? value) =>
      ConnectionKind.values.where((k) => k.name == value).firstOrNull ?? ConnectionKind.friend;
}

/// A friend, a request or a blocked user of the signed-in user.
@immutable
class SocialConnection {
  final PublicUser user;
  final ConnectionKind kind;

  /// When the friendship started or the request/block was made.
  final DateTime since;

  /// For friends: the signed-in user sent the original request (the other user accepted it).
  final bool requestedByMe;

  const SocialConnection({required this.user, required this.kind, required this.since, this.requestedByMe = false});

  factory SocialConnection.fromJson(Map<String, dynamic> json) => SocialConnection(
        user: PublicUser.fromJson(json),
        kind: ConnectionKind.parse(json['kind']),
        since: DateTime.parse(json['since'] as String),
        requestedByMe: json['requested_by_me'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        ...user.toJson(),
        'kind': kind.name,
        'since': since.toUtc().toIso8601String(),
        'requested_by_me': requestedByMe,
      };
}

/// Friends, requests and blocked users, as last confirmed by the server.
@immutable
class SocialGraph {
  final List<SocialConnection> connections;

  /// Loaded from the device cache because the server was unreachable.
  final bool isOffline;

  const SocialGraph({required this.connections, this.isOffline = false});

  static const empty = SocialGraph(connections: []);

  /// How long an accepted request is shown as news.
  static const acceptedNoticePeriod = Duration(days: 7);

  List<SocialConnection> _of(ConnectionKind kind) {
    final list = connections.where((c) => c.kind == kind).toList()
      ..sort((a, b) => (a.user.nickname ?? '').toLowerCase().compareTo((b.user.nickname ?? '').toLowerCase()));
    return list;
  }

  List<SocialConnection> get friends => _of(ConnectionKind.friend);
  List<SocialConnection> get incoming => _of(ConnectionKind.incoming);
  List<SocialConnection> get outgoing => _of(ConnectionKind.outgoing);
  List<SocialConnection> get blocked => _of(ConnectionKind.blocked);

  /// Friends who recently accepted the signed-in user's request, newest first.
  List<SocialConnection> recentlyAccepted(DateTime now) => connections
      .where(
          (c) => c.kind == ConnectionKind.friend && c.requestedByMe && now.difference(c.since) < acceptedNoticePeriod)
      .toList()
    ..sort((a, b) => b.since.compareTo(a.since));

  SocialGraph copyWith({bool? isOffline}) =>
      SocialGraph(connections: connections, isOffline: isOffline ?? this.isOffline);
}

/// Another user's profile (or the user's own) as allowed by the owner's privacy
/// settings. Statistics and communities are null when hidden.
@immutable
class PublicProfile {
  final PublicUser user;
  final String? bio;
  final Relationship relationship;
  final bool statsVisible;
  final int? activeHabits;
  final int? weekCompletedDays;
  final int? weekEligibleDays;
  final int? friendsCount;
  final bool communitiesVisible;

  /// Template ids: all of the owner's communities on the own profile, otherwise only
  /// the ones both users belong to.
  final List<String>? communities;

  const PublicProfile({
    required this.user,
    required this.relationship,
    this.bio,
    this.statsVisible = false,
    this.activeHabits,
    this.weekCompletedDays,
    this.weekEligibleDays,
    this.friendsCount,
    this.communitiesVisible = false,
    this.communities,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        user: PublicUser.fromJson(json),
        bio: json['bio'] as String?,
        relationship: Relationship.parse(json['relationship']),
        statsVisible: json['stats_visible'] as bool? ?? false,
        activeHabits: json['active_habits'] as int?,
        weekCompletedDays: json['week_completed_days'] as int?,
        weekEligibleDays: json['week_eligible_days'] as int?,
        friendsCount: json['friends_count'] as int?,
        communitiesVisible: json['communities_visible'] as bool? ?? false,
        communities: (json['communities'] as List<dynamic>?)?.cast<String>(),
      );

  PublicProfile withRelationship(Relationship relationship) => PublicProfile(
        user: user,
        bio: bio,
        relationship: relationship,
        statsVisible: statsVisible,
        activeHabits: activeHabits,
        weekCompletedDays: weekCompletedDays,
        weekEligibleDays: weekEligibleDays,
        friendsCount: friendsCount,
        communitiesVisible: communitiesVisible,
        communities: communities,
      );

  /// Weekly consistency in percent, when visible and scored.
  double? get weekConsistency {
    final completed = weekCompletedDays;
    final eligible = weekEligibleDays;
    return completed == null || eligible == null || eligible == 0 ? null : completed * 100 / eligible;
  }
}

/// Server answer to a nickname check while typing.
enum NicknameStatus { available, taken, invalid }

/// Why a social operation failed.
enum SocialFailure {
  /// Social actions need a connection.
  offline,
  network,
  nicknameTaken,
  nicknameInvalid,

  /// The user does not exist — or does not want to be found; deliberately the same.
  notFound,

  /// The signed-in user blocked this user and must unblock first.
  blockedByMe,

  /// For example a request to oneself.
  notAllowed,
  unauthorized,
  unknown,
}

final class SocialException implements Exception {
  final SocialFailure failure;

  const SocialException(this.failure);

  @override
  String toString() => 'SocialException($failure)';
}
