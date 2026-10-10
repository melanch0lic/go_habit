import 'dart:async';

import 'package:go_habit/core/app_connect/src/app_connect.dart';
import 'package:go_habit/core/sync/sync_remote_api.dart';

/// In-memory server with the semantics of the Supabase schema in `supabase/migrations`:
/// per-user isolation (RLS), server-assigned `updated_at`, idempotent upserts,
/// sticky habit tombstones cascading to completions and the completion → habit foreign key.
class FakeSyncRemoteApi implements SyncRemoteApi {
  final String? Function() currentUserId;

  FakeSyncRemoteApi({required this.currentUserId});

  final _habits = <String, Map<String, RemoteHabit>>{};
  final _completions = <String, Map<String, RemoteCompletion>>{};
  var _clock = DateTime.utc(2026, 10, 9, 12);

  /// Failure injection, consumed by the next matching call.
  SyncException? failNextHabitUpsert;
  SyncException? failNextCompletionUpsert;
  SyncException? failNextFetch;

  /// Applies the next completion upsert on the server, then fails as if the response was lost.
  bool loseNextCompletionResponse = false;

  /// Habit ids the server rejects permanently (e.g. invalid category).
  final rejectedHabitIds = <String>{};

  /// Called before each fetch; lets tests change the session mid-request.
  void Function()? beforeFetch;

  int habitUpsertCalls = 0;
  int completionUpsertCalls = 0;

  Map<String, RemoteHabit> habitsOf(String userId) => _habits.putIfAbsent(userId, () => {});
  Map<String, RemoteCompletion> completionsOf(String userId) => _completions.putIfAbsent(userId, () => {});

  DateTime _tick() => _clock = _clock.add(const Duration(milliseconds: 1));

  String get _user {
    final id = currentUserId();
    if (id == null) throw const SyncAuthException('not signed in');
    return id;
  }

  /// Simulates a write made by another device of [userId].
  void serverPutHabit(String userId, RemoteHabit habit) => _writeHabit(userId, habit);

  void serverPutCompletion(String userId, RemoteCompletion completion) {
    final habitDeletedAt = habitsOf(userId)[completion.habitId]?.deletedAt;
    completionsOf(userId)['${completion.habitId}/${completion.completedOn}'] = _stampCompletion(
      completion,
      deletedAt: completion.deletedAt ?? (habitDeletedAt == null ? null : _clock),
    );
  }

  void _writeHabit(String userId, RemoteHabit habit) {
    final table = habitsOf(userId);
    final previous = table[habit.id];
    // Delete wins: a tombstone is never cleared.
    final stored = table[habit.id] = _stamp(habit, keepDeletedAt: previous?.deletedAt);
    if (previous?.deletedAt == null && stored.deletedAt != null) {
      final completions = completionsOf(userId);
      for (final entry in completions.entries.toList()) {
        if (entry.value.habitId == habit.id && entry.value.deletedAt == null) {
          completions[entry.key] = _stampCompletion(entry.value, deletedAt: stored.deletedAt);
        }
      }
    }
  }

  RemoteCompletion _stampCompletion(RemoteCompletion c, {required DateTime? deletedAt}) => RemoteCompletion(
        id: c.id,
        habitId: c.habitId,
        completedOn: c.completedOn,
        updatedAt: _tick(),
        deletedAt: deletedAt,
      );

  RemoteHabit _stamp(RemoteHabit h, {DateTime? keepDeletedAt}) => RemoteHabit(
        id: h.id,
        categoryId: h.categoryId,
        title: h.title,
        description: h.description,
        icon: h.icon,
        steps: h.steps,
        isActive: h.isActive,
        createdAt: h.createdAt,
        updatedAt: _tick(),
        deletedAt: keepDeletedAt ?? h.deletedAt,
        scheduleType: h.scheduleType,
        weeklyTarget: h.weeklyTarget,
        scheduleDays: h.scheduleDays,
        streakResetOn: h.streakResetOn,
      );

  @override
  Future<void> upsertHabits(List<RemoteHabit> habits) async {
    habitUpsertCalls++;
    final failure = failNextHabitUpsert;
    if (failure != null) {
      failNextHabitUpsert = null;
      throw failure;
    }
    final user = _user;
    if (habits.any((h) => rejectedHabitIds.contains(h.id))) {
      throw const SyncRejectedException('23503: invalid category');
    }
    for (final h in habits) {
      _writeHabit(user, h);
    }
  }

  @override
  Future<void> upsertCompletions(List<RemoteCompletion> completions) async {
    completionUpsertCalls++;
    final failure = failNextCompletionUpsert;
    if (failure != null) {
      failNextCompletionUpsert = null;
      throw failure;
    }
    final user = _user;
    for (final c in completions) {
      if (!habitsOf(user).containsKey(c.habitId)) {
        throw const SyncRejectedException('23503: habit does not exist');
      }
    }
    for (final c in completions) {
      serverPutCompletion(user, c);
    }
    if (loseNextCompletionResponse) {
      loseNextCompletionResponse = false;
      throw const SyncNetworkException('connection reset');
    }
  }

  @override
  Future<List<RemoteHabit>> fetchHabits({required DateTime? updatedSince, required int limit}) async {
    _beforeFetch();
    return _page(habitsOf(_user).values, (h) => h.updatedAt!, updatedSince, limit);
  }

  @override
  Future<List<RemoteCompletion>> fetchCompletions({required DateTime? updatedSince, required int limit}) async {
    _beforeFetch();
    return _page(completionsOf(_user).values, (c) => c.updatedAt!, updatedSince, limit);
  }

  void _beforeFetch() {
    beforeFetch?.call();
    final failure = failNextFetch;
    if (failure != null) {
      failNextFetch = null;
      throw failure;
    }
  }

  static List<R> _page<R>(Iterable<R> rows, DateTime Function(R) updatedAt, DateTime? since, int limit) {
    final result = rows.where((r) => since == null || !updatedAt(r).isBefore(since)).toList()
      ..sort((a, b) => updatedAt(a).compareTo(updatedAt(b)));
    return result.take(limit).toList();
  }
}

// ignore: must_be_immutable
class FakeAppConnect implements IAppConnect {
  bool online = true;
  final _changes = StreamController<bool>.broadcast();

  void goOffline() => online = false;

  void goOnline() {
    online = true;
    _changes.add(true);
  }

  @override
  Future<bool> hasConnect() async => online;

  @override
  Stream<bool> get onConnectChanged => _changes.stream;
}
