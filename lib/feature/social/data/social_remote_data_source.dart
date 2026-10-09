import 'dart:async';
import 'dart:io';

import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server access for the social layer. Throws [SocialException].
abstract interface class SocialRemoteDataSource {
  Future<MyProfile> fetchMyProfile();
  Future<MyProfile> updateMyProfile(Map<String, Object?> fields);
  Future<NicknameStatus> nicknameStatus(String nickname);
  Future<List<UserSearchResult>> search(String nickname);
  Future<PublicProfile> publicProfile(String publicId, {required CalendarDay today});

  /// Runs one of the relationship functions and returns the resulting relationship.
  Future<Relationship> relationshipAction(RelationshipAction action, String publicId);
  Future<List<SocialConnection>> fetchGraph();
  Future<List<LeaderboardEntry>> fetchFriendsLeaderboard({required CalendarDay today});
}

enum RelationshipAction {
  send('send_friend_request'),
  accept('respond_friend_request'),
  reject('respond_friend_request'),
  cancel('cancel_friend_request'),
  remove('remove_friend'),
  block('block_user'),
  unblock('unblock_user');

  final String function;

  const RelationshipAction(this.function);
}

class SupabaseSocialDataSource implements SocialRemoteDataSource {
  final SupabaseClient _client;
  final Duration _timeout;

  SupabaseSocialDataSource(this._client, {Duration timeout = const Duration(seconds: 15)}) : _timeout = timeout;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SocialException(SocialFailure.unauthorized);
    return id;
  }

  @override
  Future<MyProfile> fetchMyProfile() => _guard(() async {
        final row = await _client.from('profile').select(MyProfile.columns).eq('id', _userId).single();
        return MyProfile.fromJson(row);
      });

  @override
  Future<MyProfile> updateMyProfile(Map<String, Object?> fields) => _guard(() async {
        final row = await _client.from('profile').update(fields).eq('id', _userId).select(MyProfile.columns).single();
        return MyProfile.fromJson(row);
      });

  @override
  Future<NicknameStatus> nicknameStatus(String nickname) => _guard(() async {
        final status = await _client.rpc<String>('nickname_status', params: {'p_nickname': nickname});
        return NicknameStatus.values.where((s) => s.name == status).firstOrNull ?? NicknameStatus.invalid;
      });

  @override
  Future<List<UserSearchResult>> search(String nickname) => _guard(() async {
        final rows = await _client.rpc<List<dynamic>>('search_profiles', params: {'p_nickname': nickname});
        return rows.cast<Map<String, dynamic>>().map(UserSearchResult.fromJson).toList();
      });

  @override
  Future<PublicProfile> publicProfile(String publicId, {required CalendarDay today}) => _guard(() async {
        final rows = await _client.rpc<List<dynamic>>('get_public_profile', params: {
          'p_public_id': publicId,
          'p_today': today.toIsoString(),
        });
        if (rows.isEmpty) throw const SocialException(SocialFailure.notFound);
        return PublicProfile.fromJson(rows.first as Map<String, dynamic>);
      });

  @override
  Future<Relationship> relationshipAction(RelationshipAction action, String publicId) => _guard(() async {
        final result = await _client.rpc<String>(action.function, params: {
          'p_public_id': publicId,
          if (action == RelationshipAction.accept) 'p_accept': true,
          if (action == RelationshipAction.reject) 'p_accept': false,
        });
        return Relationship.parse(result);
      });

  @override
  Future<List<SocialConnection>> fetchGraph() => _guard(() async {
        final rows = await _client.rpc<List<dynamic>>('my_social_graph');
        return rows.cast<Map<String, dynamic>>().map(SocialConnection.fromJson).toList();
      });

  @override
  Future<List<LeaderboardEntry>> fetchFriendsLeaderboard({required CalendarDay today}) => _guard(() async {
        final rows = await _client.rpc<List<dynamic>>('friends_leaderboard', params: {'p_today': today.toIsoString()});
        return rows.cast<Map<String, dynamic>>().map(LeaderboardEntry.fromJson).toList();
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on PostgrestException catch (e) {
      throw SocialException(mapPostgrestFailure(e.code));
    } on AuthException {
      throw const SocialException(SocialFailure.unauthorized);
    } on SocketException {
      throw const SocialException(SocialFailure.network);
    } on http.ClientException {
      throw const SocialException(SocialFailure.network);
    } on TimeoutException {
      throw const SocialException(SocialFailure.network);
    }
  }

  /// [code] is a Postgres SQLSTATE, a PostgREST code or an HTTP status.
  static SocialFailure mapPostgrestFailure(String? code) => switch (code) {
        // Unique index on lower(nickname): someone else took it meanwhile.
        '23505' => SocialFailure.nicknameTaken,
        // Check constraints (format, reserved names, bio length).
        '23514' => SocialFailure.nicknameInvalid,
        // Unknown user — or one who blocked the caller; deliberately indistinguishable.
        'P0002' || 'PGRST116' => SocialFailure.notFound,
        'P0004' => SocialFailure.blockedByMe,
        '22023' => SocialFailure.notAllowed,
        '42501' || '401' || '403' => SocialFailure.unauthorized,
        final code? when code.startsWith('PGRST3') => SocialFailure.unauthorized,
        _ => SocialFailure.unknown,
      };
}
