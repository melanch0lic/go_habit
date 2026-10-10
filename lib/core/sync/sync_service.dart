import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:go_habit/core/app_connect/src/app_connect.dart';
import 'package:go_habit/core/database/dao/habit_completion_dao.dart';
import 'package:go_habit/core/database/dao/habits_dao.dart';
import 'package:go_habit/core/database/dao/sync_state_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/sync/sync_remote_api.dart';
import 'package:l/l.dart';

/// Lets repositories ask for local changes to be uploaded soon.
abstract interface class SyncScheduler {
  void requestSync();
}

/// Session-level operations on the local copy of the user's data.
abstract interface class SessionDataManager {
  /// Runs a synchronization now. Returns true if it completed.
  Future<bool> syncNow();

  /// Number of local changes that have not reached the server.
  Future<int> pendingChangesCount();

  /// Deletes the signed-in user's local data.
  Future<void> clearLocalData();
}

/// Offline-first synchronization between Drift and Supabase.
///
/// Every run: push pending local rows → pull server rows changed since the last
/// cursor. Runs are serialized, triggered by sign-in, connectivity, local writes
/// (debounced) and retried with exponential backoff. See docs/SYNC.md.
class SyncService implements SyncScheduler, SessionDataManager {
  final AppDatabase _db;
  final SyncRemoteApi _remote;
  final IAppConnect _appConnect;
  final Stream<String?> _userIdChanges;
  final String? Function() _currentUserId;
  final Duration _debounce;
  final Duration _requestTimeout;
  final int _pageSize;

  final HabitsDao _habitsDao;
  final HabitCompletionDao _completionDao;
  final SyncStateDao _stateDao;

  final _lock = _SerialLock();
  Future<bool>? _inFlight;
  bool _rerunRequested = false;
  int _failedAttempts = 0;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<bool>? _connectSubscription;
  final _synced = StreamController<void>.broadcast();

  static const ownerKey = 'owner_user_id';
  static const habitCursorKey = 'habit_cursor';
  static const completionCursorKey = 'habit_completion_cursor';

  /// Re-reads a short window before the cursor: a row committed slightly later than a
  /// newer row may carry an older timestamp. Re-applying rows is idempotent.
  static const cursorOverlap = Duration(seconds: 5);
  static const _maxRetryDelay = Duration(minutes: 5);

  SyncService({
    required AppDatabase database,
    required SyncRemoteApi remoteApi,
    required IAppConnect appConnect,
    required Stream<String?> userIdChanges,
    required String? Function() currentUserId,
    Duration debounce = const Duration(milliseconds: 800),
    Duration requestTimeout = const Duration(seconds: 30),
    int pageSize = 500,
  })  : _db = database,
        _remote = remoteApi,
        _appConnect = appConnect,
        _userIdChanges = userIdChanges,
        _currentUserId = currentUserId,
        _debounce = debounce,
        _requestTimeout = requestTimeout,
        _pageSize = pageSize,
        _habitsDao = HabitsDao(database),
        _completionDao = HabitCompletionDao(database),
        _stateDao = SyncStateDao(database);

  void start() {
    _authSubscription ??= _userIdChanges.distinct().listen(_onUserChanged);
    _connectSubscription ??= _appConnect.onConnectChanged.listen((online) {
      if (!online) return;
      _failedAttempts = 0;
      _scheduleRun(Duration.zero);
    });
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    await _authSubscription?.cancel();
    await _connectSubscription?.cancel();
    await _synced.close();
  }

  /// Emits after every run that completed against the server, e.g. so views of
  /// server-computed data (community rankings) can reload.
  Stream<void> get onSynced => _synced.stream;

  @override
  void requestSync() => _scheduleRun(_debounce);

  @override
  Future<bool> syncNow() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      _rerunRequested = true;
      return inFlight;
    }
    final run = _lock.run(_runUntilSettled).whenComplete(() {
      _inFlight = null;
      // A request that arrived after the last loop check must not be lost.
      if (_rerunRequested && !(_retryTimer?.isActive ?? false)) _scheduleRun(Duration.zero);
      _rerunRequested = false;
    });
    _inFlight = run;
    return run;
  }

  @override
  Future<int> pendingChangesCount() async => await _habitsDao.countPending() + await _completionDao.countPending();

  @override
  Future<void> clearLocalData() async {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    // Waits for an in-flight run so it cannot write after the wipe.
    await _lock.run(_db.clearUserData);
  }

  /// The local database belongs to one account at a time. Data without an owner
  /// (fresh install, or upgraded from v1) is adopted by the signing-in user; data of
  /// a different user is removed so it can neither be shown nor uploaded.
  Future<void> _onUserChanged(String? userId) async {
    if (userId == null) {
      // Signed out (or session lost). Keep the data: the same user may sign back in.
      _debounceTimer?.cancel();
      _retryTimer?.cancel();
      return;
    }
    await _lock.run(() async {
      final owner = await _stateDao.read(ownerKey);
      if (owner == userId) return;
      if (owner != null) {
        l.i('Local data belongs to another account; clearing it.');
        await _db.clearUserData();
      }
      await _stateDao.write(ownerKey, userId);
    });
    _failedAttempts = 0;
    _scheduleRun(Duration.zero);
  }

  void _scheduleRun(Duration delay) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () => unawaited(syncNow()));
  }

  Future<bool> _runUntilSettled() async {
    bool completed;
    do {
      _rerunRequested = false;
      completed = await _runOnce();
    } while (completed && _rerunRequested);
    return completed;
  }

  Future<bool> _runOnce() async {
    final userId = _currentUserId();
    if (userId == null || await _stateDao.read(ownerKey) != userId) return false;
    if (!await _appConnect.hasConnect()) return false; // resumed by onConnectChanged

    try {
      await _pushHabits(userId);
      await _pushCompletions(userId);
      await _pullHabits(userId);
      await _pullCompletions(userId);
      _failedAttempts = 0;
      _retryTimer?.cancel();
      if (!_synced.isClosed) _synced.add(null);
      return true;
    } on _AccountChanged {
      return false;
    } on SyncAuthException catch (e) {
      // supabase_flutter refreshes the session itself; the auth listener restarts us.
      l.w('Sync paused, session is not valid: $e');
      return false;
    } on SyncException catch (e) {
      l.w('Sync failed, will retry: $e');
      _scheduleRetry();
      return false;
    } on Object catch (e, stackTrace) {
      l.e('Unexpected sync failure: $e', stackTrace);
      _scheduleRetry();
      return false;
    }
  }

  void _scheduleRetry() {
    _failedAttempts++;
    final seconds = math.min(2 * math.pow(2, _failedAttempts - 1).toInt(), _maxRetryDelay.inSeconds);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () => unawaited(syncNow()));
  }

  Future<T> _call<T>(String userId, Future<T> Function() request) async {
    final T result;
    try {
      result = await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw const SyncNetworkException('request timed out');
    }
    // Never apply a response that was fetched for an account that is no longer signed in.
    if (_currentUserId() != userId) throw const _AccountChanged();
    return result;
  }

  // ---------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------

  Future<void> _pushHabits(String userId) async {
    final pending = await _habitsDao.getPending();
    await _pushInBatch(
      userId,
      pending,
      upload: (rows) => _remote.upsertHabits(rows.map(_toRemoteHabit).toList()),
      onPushed: _habitsDao.markPushed,
      describe: (h) => 'habit ${h.id}',
    );
  }

  Future<void> _pushCompletions(String userId) async {
    final pending = await _completionDao.getPending();
    await _pushInBatch(
      userId,
      pending,
      upload: (rows) => _remote.upsertCompletions(rows.map(_toRemoteCompletion).toList()),
      onPushed: _completionDao.markPushed,
      describe: (c) => 'completion ${c.id}',
    );
  }

  /// Uploads [rows] in one request. If the server rejects the batch, rows are retried
  /// one by one so that a single invalid row cannot block the others. Rejected rows stay
  /// pending (they are never silently discarded) and are reported in the log.
  Future<void> _pushInBatch<R>(
    String userId,
    List<R> rows, {
    required Future<void> Function(List<R>) upload,
    required Future<void> Function(R) onPushed,
    required String Function(R) describe,
  }) async {
    if (rows.isEmpty) return;
    try {
      await _call(userId, () => upload(rows));
      for (final row in rows) {
        await onPushed(row);
      }
    } on SyncRejectedException {
      for (final row in rows) {
        try {
          await _call(userId, () => upload([row]));
          await onPushed(row);
        } on SyncRejectedException catch (e) {
          l.e('Server rejected ${describe(row)}: $e', StackTrace.current);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------

  Future<void> _pullHabits(String userId) => _pull<RemoteHabit>(
        userId,
        cursorKey: habitCursorKey,
        fetch: (since) => _remote.fetchHabits(updatedSince: since, limit: _pageSize),
        updatedAt: (h) => h.updatedAt!,
        apply: (page) => _habitsDao.applyRemote(
          [
            for (final h in page)
              if (h.deletedAt == null) _toHabitCompanion(h),
          ],
          deletedIds: {
            for (final h in page)
              if (h.deletedAt != null) h.id,
          },
        ),
      );

  Future<void> _pullCompletions(String userId) => _pull<RemoteCompletion>(
        userId,
        cursorKey: completionCursorKey,
        fetch: (since) => _remote.fetchCompletions(updatedSince: since, limit: _pageSize),
        updatedAt: (c) => c.updatedAt!,
        apply: (page) => _completionDao.applyRemote(
          [
            for (final c in page)
              if (c.deletedAt == null) _toCompletionCompanion(c),
          ],
          deletedIds: {
            for (final c in page)
              if (c.deletedAt != null) c.id,
          },
        ),
      );

  Future<void> _pull<R>(
    String userId, {
    required String cursorKey,
    required Future<List<R>> Function(DateTime? since) fetch,
    required DateTime Function(R) updatedAt,
    required Future<void> Function(List<R>) apply,
  }) async {
    final stored = await _stateDao.read(cursorKey);
    var since = stored == null ? null : DateTime.parse(stored).subtract(cursorOverlap);

    while (true) {
      final page = await _call(userId, () => fetch(since));
      if (page.isEmpty) return;
      final newest = updatedAt(page.last);
      await _db.transaction(() async {
        await apply(page);
        await _stateDao.write(cursorKey, newest.toUtc().toIso8601String());
      });
      if (page.length < _pageSize) return;
      if (since != null && !newest.isAfter(since)) {
        l.w('Pull of $cursorKey made no progress: $_pageSize rows share one timestamp');
        return;
      }
      since = newest;
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------------

  static RemoteHabit _toRemoteHabit(Habit h) => RemoteHabit(
        id: h.id,
        categoryId: h.categoryId,
        title: h.title,
        description: h.description,
        icon: h.icon.isEmpty ? '🎯' : h.icon,
        steps: h.steps,
        isActive: h.isActive,
        createdAt: h.createdAt,
        deletedAt: h.deletedAt,
        scheduleType: h.scheduleType,
        weeklyTarget: h.weeklyTarget,
        scheduleDays: h.scheduleDays,
        streakResetOn: h.streakResetOn,
      );

  static HabitsCompanion _toHabitCompanion(RemoteHabit h) => HabitsCompanion(
        id: Value(h.id),
        title: Value(h.title),
        description: Value(h.description),
        categoryId: Value(h.categoryId),
        icon: Value(h.icon),
        steps: Value(h.steps),
        isActive: Value(h.isActive),
        createdAt: Value(h.createdAt.toLocal()),
        updatedAt: Value(h.updatedAt!.toLocal()),
        scheduleType: Value(h.scheduleType),
        weeklyTarget: Value(h.weeklyTarget),
        scheduleDays: Value(h.scheduleDays),
        streakResetOn: Value(h.streakResetOn),
      );

  static RemoteCompletion _toRemoteCompletion(HabitCompletion c) => RemoteCompletion(
        id: c.id,
        habitId: c.habitId,
        completedOn: c.completedOn,
        deletedAt: c.deletedAt,
      );

  static HabitCompletionsCompanion _toCompletionCompanion(RemoteCompletion c) => HabitCompletionsCompanion(
        id: Value(c.id),
        habitId: Value(c.habitId),
        completedOn: Value(c.completedOn),
        updatedAt: Value(c.updatedAt!.toLocal()),
      );
}

final class _AccountChanged implements Exception {
  const _AccountChanged();
}

/// Runs async actions one at a time, in call order.
class _SerialLock {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
