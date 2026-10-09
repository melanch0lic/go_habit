import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/sync/supabase_sync_remote_api.dart';
import 'package:go_habit/core/sync/sync_remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SyncException map(String? code) => SupabaseSyncRemoteApi.mapPostgrest(PostgrestException(message: 'x', code: code));

  test('expired or missing session pauses sync', () {
    expect(map('PGRST301'), isA<SyncAuthException>());
    expect(map('401'), isA<SyncAuthException>());
  });

  test('constraint and permission violations are permanent', () {
    expect(map('23505'), isA<SyncRejectedException>()); // unique
    expect(map('23503'), isA<SyncRejectedException>()); // foreign key
    expect(map('42501'), isA<SyncRejectedException>()); // RLS / privilege
    expect(map('22P02'), isA<SyncRejectedException>()); // invalid input
    expect(map('PGRST204'), isA<SyncRejectedException>()); // unknown column
  });

  test('server-side trouble is retried', () {
    expect(map('40001'), isA<SyncServerException>()); // serialization failure
    expect(map('57014'), isA<SyncServerException>()); // statement timeout
    expect(map('503'), isA<SyncServerException>());
    expect(map(null), isA<SyncServerException>());
  });

  test('pushed habits never carry user_id or updated_at', () {
    final json = RemoteHabit(
      id: 'h',
      categoryId: 'sport',
      title: 't',
      description: null,
      icon: 'i',
      steps: 0,
      isActive: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ).toJson();
    expect(json.keys, isNot(contains('user_id')));
    expect(json.keys, isNot(contains('updated_at')));
  });
}
