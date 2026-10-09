import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_habit/core/sync/sync_remote_api.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncRemoteApi implements SyncRemoteApi {
  final SupabaseClient _client;

  SupabaseSyncRemoteApi(this._client);

  @override
  Future<void> upsertHabits(List<RemoteHabit> habits) => _guard(() async {
        // missing=default lets the server fill user_id from auth.uid().
        await _client
            .from('habit')
            .upsert(habits.map((h) => h.toJson()).toList(), onConflict: 'id', defaultToNull: false);
      });

  @override
  Future<void> upsertCompletions(List<RemoteCompletion> completions) => _guard(() async {
        await _client.from('habit_completion').upsert(
              completions.map((c) => c.toJson()).toList(),
              onConflict: 'habit_id,completed_on',
              defaultToNull: false,
            );
      });

  @override
  Future<List<RemoteHabit>> fetchHabits({required DateTime? updatedSince, required int limit}) => _guard(() async {
        var query = _client.from('habit').select(RemoteHabit.columns);
        if (updatedSince != null) query = query.gte('updated_at', updatedSince.toUtc().toIso8601String());
        final rows = await query.order('updated_at', ascending: true).order('id', ascending: true).limit(limit);
        return rows.map(RemoteHabit.fromJson).toList();
      });

  @override
  Future<List<RemoteCompletion>> fetchCompletions({required DateTime? updatedSince, required int limit}) =>
      _guard(() async {
        var query = _client.from('habit_completion').select(RemoteCompletion.columns);
        if (updatedSince != null) query = query.gte('updated_at', updatedSince.toUtc().toIso8601String());
        final rows = await query.order('updated_at', ascending: true).order('id', ascending: true).limit(limit);
        return rows.map(RemoteCompletion.fromJson).toList();
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on PostgrestException catch (e) {
      throw mapPostgrest(e);
    } on AuthException catch (e) {
      throw SyncAuthException(e.message);
    } on http.ClientException catch (e) {
      throw SyncNetworkException(e.message);
    } on TimeoutException catch (e) {
      throw SyncNetworkException(e.message ?? 'timeout');
    }
  }

  static final _sqlState = RegExp(r'^[0-9A-Z]{5}$');

  /// [PostgrestException.code] is a PostgREST error (`PGRSTxxx`), a Postgres SQLSTATE,
  /// or the HTTP status when the response had no JSON body.
  @visibleForTesting
  static SyncException mapPostgrest(PostgrestException e) {
    final code = e.code ?? '';
    final message = '${e.code}: ${e.message}';
    if (code.startsWith('PGRST3') || code == '401' || code == '403') {
      return SyncAuthException(message);
    }
    if (_sqlState.hasMatch(code)) {
      // Class 22 (data exception), 23 (integrity), 42 (privilege/syntax) are permanent.
      if (code.startsWith('22') || code.startsWith('23') || code.startsWith('42')) {
        return SyncRejectedException(message);
      }
      return SyncServerException(message);
    }
    if (code.startsWith('PGRST1') || code.startsWith('PGRST2')) {
      return SyncRejectedException(message);
    }
    return SyncServerException(message);
  }
}
