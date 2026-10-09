import 'dart:async';
import 'dart:convert';

import 'package:go_habit/core/app_connect/src/app_connect.dart';
import 'package:go_habit/core/database/dao/social_cache_dao.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/social/data/social_remote_data_source.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/nickname_rules.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

class SocialRepositoryImpl implements SocialRepository {
  final SocialRemoteDataSource _remote;
  final SocialCacheDao _cache;
  final IAppConnect _appConnect;
  final CalendarDay Function() _today;
  final _changes = StreamController<void>.broadcast();

  static const _profileKey = 'my_profile';
  static const _graphKey = 'social_graph';

  SocialRepositoryImpl({
    required SocialRemoteDataSource remote,
    required SocialCacheDao cache,
    required IAppConnect appConnect,
    CalendarDay Function()? today,
  })  : _remote = remote,
        _cache = cache,
        _appConnect = appConnect,
        _today = today ?? CalendarDay.today;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<MyProfile> loadMyProfile() async {
    try {
      return await _saveProfile(await _remote.fetchMyProfile());
    } on SocialException catch (e) {
      if (e.failure != SocialFailure.network) rethrow;
      final cached = await _cache.read(_profileKey);
      if (cached == null) rethrow;
      return MyProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  @override
  Future<MyProfile> updateProfile({required String nickname, String? bio, String? avatar}) async {
    await _requireConnection();
    final trimmedBio = bio?.trim();
    return _saveProfile(await _remote.updateMyProfile({
      'nickname': NicknameRules.normalize(nickname),
      'bio': trimmedBio == null || trimmedBio.isEmpty ? null : trimmedBio,
      'avatar': avatar,
    }));
  }

  @override
  Future<MyProfile> updatePrivacy({required ProfileVisibility stats, required ProfileVisibility communities}) async {
    await _requireConnection();
    return _saveProfile(await _remote.updateMyProfile({
      'stats_visibility': stats.name,
      'communities_visibility': communities.name,
    }));
  }

  Future<MyProfile> _saveProfile(MyProfile profile) async {
    await _cache.write(_profileKey, jsonEncode(profile.toJson()));
    return profile;
  }

  @override
  Future<NicknameStatus> nicknameStatus(String nickname) async {
    if (NicknameRules.validate(nickname) != null) return NicknameStatus.invalid;
    await _requireConnection();
    return _remote.nicknameStatus(NicknameRules.normalize(nickname));
  }

  @override
  Future<List<UserSearchResult>> search(String nickname) async {
    final query = NicknameRules.normalize(nickname);
    if (NicknameRules.validate(query) != null) return const [];
    await _requireConnection();
    return _remote.search(query);
  }

  @override
  Future<PublicProfile> publicProfile(String publicId) async {
    await _requireConnection();
    return _remote.publicProfile(publicId, today: _today());
  }

  @override
  Future<Relationship> sendRequest(String publicId) => _act(RelationshipAction.send, publicId);

  @override
  Future<Relationship> respondToRequest(String publicId, {required bool accept}) =>
      _act(accept ? RelationshipAction.accept : RelationshipAction.reject, publicId);

  @override
  Future<Relationship> cancelRequest(String publicId) => _act(RelationshipAction.cancel, publicId);

  @override
  Future<Relationship> removeFriend(String publicId) => _act(RelationshipAction.remove, publicId);

  @override
  Future<Relationship> block(String publicId) => _act(RelationshipAction.block, publicId);

  @override
  Future<Relationship> unblock(String publicId) => _act(RelationshipAction.unblock, publicId);

  /// Only the server's answer counts; nothing is queued or assumed while offline.
  Future<Relationship> _act(RelationshipAction action, String publicId) async {
    await _requireConnection();
    final relationship = await _remote.relationshipAction(action, publicId);
    _changes.add(null);
    return relationship;
  }

  @override
  Future<SocialGraph> loadGraph() async {
    try {
      final connections = await _remote.fetchGraph();
      await _cache.write(_graphKey, jsonEncode([for (final c in connections) c.toJson()]));
      return SocialGraph(connections: connections);
    } on SocialException catch (e) {
      if (e.failure != SocialFailure.network) rethrow;
      final cached = await _cache.read(_graphKey);
      if (cached == null) rethrow;
      final rows = (jsonDecode(cached) as List<dynamic>).cast<Map<String, dynamic>>();
      return SocialGraph(connections: rows.map(SocialConnection.fromJson).toList(), isOffline: true);
    }
  }

  @override
  Future<CommunityLeaderboard> friendsLeaderboard() async {
    await _requireConnection();
    return CommunityLeaderboard.fromRows(await _remote.fetchFriendsLeaderboard(today: _today()));
  }

  Future<void> _requireConnection() async {
    if (!await _appConnect.hasConnect()) throw const SocialException(SocialFailure.offline);
  }

  Future<void> dispose() => _changes.close();
}
