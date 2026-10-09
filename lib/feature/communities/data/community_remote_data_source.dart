import 'dart:async';
import 'dart:io';

import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server access for communities. Throws [CommunityException].
abstract interface class CommunityRemoteDataSource {
  Future<List<HabitTemplate>> fetchTemplates();
  Future<Map<String, int>> fetchMemberCounts();
  Future<List<CommunityMembership>> fetchMemberships();
  Future<CommunityMembership> join({required String templateId, required CalendarDay joinedOn, String? habitId});
  Future<void> leave(String templateId);
  Future<List<LeaderboardEntry>> fetchLeaderboard({required String templateId, required CalendarDay today});
}

class SupabaseCommunityDataSource implements CommunityRemoteDataSource {
  final SupabaseClient _client;
  final Duration _timeout;

  SupabaseCommunityDataSource(this._client, {Duration timeout = const Duration(seconds: 15)}) : _timeout = timeout;

  @override
  Future<List<HabitTemplate>> fetchTemplates() => _guard(() async {
        final rows = await _client.from('habit_template').select(HabitTemplate.columns).order('sort_order');
        return rows.map(HabitTemplate.fromJson).toList();
      });

  @override
  Future<Map<String, int>> fetchMemberCounts() => _guard(() async {
        final rows = await _client.rpc<List<dynamic>>('community_member_counts');
        return {
          for (final row in rows.cast<Map<String, dynamic>>()) row['template_id'] as String: row['member_count'] as int,
        };
      });

  @override
  Future<List<CommunityMembership>> fetchMemberships() => _guard(() async {
        // RLS returns only the caller's rows.
        final rows = await _client.from('community_membership').select('template_id, habit_id, joined_on');
        return rows.map(CommunityMembership.fromJson).toList();
      });

  @override
  Future<CommunityMembership> join({required String templateId, required CalendarDay joinedOn, String? habitId}) =>
      _guard(() async {
        final row = await _client.rpc<Map<String, dynamic>>('join_community', params: {
          'p_template_id': templateId,
          'p_habit_id': habitId,
          'p_joined_on': joinedOn.toIsoString(),
        });
        return CommunityMembership.fromJson(row);
      });

  @override
  Future<void> leave(String templateId) => _guard(() async {
        await _client.from('community_membership').delete().eq('template_id', templateId);
      });

  /// The top of the ranking shown in the app; the caller's own row is always added.
  static const leaderboardSize = 20;

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({required String templateId, required CalendarDay today}) =>
      _guard(() async {
        final rows = await _client.rpc<List<dynamic>>('community_leaderboard', params: {
          'p_template_id': templateId,
          'p_today': today.toIsoString(),
          'p_limit': leaderboardSize,
        });
        return rows.cast<Map<String, dynamic>>().map(LeaderboardEntry.fromJson).toList();
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on PostgrestException catch (e) {
      throw CommunityException(mapPostgrestFailure(e.code));
    } on AuthException {
      throw const CommunityException(CommunityFailure.unauthorized);
    } on SocketException {
      throw const CommunityException(CommunityFailure.network);
    } on http.ClientException {
      throw const CommunityException(CommunityFailure.network);
    } on TimeoutException {
      throw const CommunityException(CommunityFailure.network);
    }
  }

  /// [code] is a Postgres SQLSTATE, a PostgREST code or an HTTP status.
  static CommunityFailure mapPostgrestFailure(String? code) => switch (code) {
        // The ranked habit is not on the server yet (composite foreign key).
        '23503' => CommunityFailure.habitNotSynced,
        // Retired community or deleted habit (guard trigger); habit already ranked elsewhere.
        '23514' || '23505' => CommunityFailure.notAllowed,
        '42501' || '401' || '403' => CommunityFailure.unauthorized,
        final code? when code.startsWith('PGRST3') => CommunityFailure.unauthorized,
        _ => CommunityFailure.unknown,
      };
}
