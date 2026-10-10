import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/habit_completion_dao.dart';
import 'package:go_habit/core/database/dao/habits_dao.dart';
import 'package:go_habit/core/database/dao/sync_state_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/sync/sync_remote_api.dart';
import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/core/utils/calendar_day.dart';

import 'fake_sync_remote_api.dart';

const alice = 'alice';
const bob = 'bob';
final day = CalendarDay(2026, 10, 9);

void main() {
  late AppDatabase db;
  late HabitsDao habitsDao;
  late HabitCompletionDao completionDao;
  late FakeSyncRemoteApi remote;
  late FakeAppConnect connect;
  late StreamController<String?> authChanges;
  late SyncService sync;
  String? currentUser;

  Future<void> signIn(String? userId) async {
    currentUser = userId;
    authChanges.add(userId);
    await pumpEventQueue();
  }

  Future<void> addLocalHabit(String id, {String title = 'Read'}) =>
      habitsDao.insertLocal(HabitsCompanion.insert(id: id, title: title, categoryId: 'education'));

  RemoteHabit remoteHabit(String id, {String title = 'Remote', DateTime? deletedAt}) => RemoteHabit(
        id: id,
        categoryId: 'sport',
        title: title,
        description: null,
        icon: '🏃',
        steps: 0,
        isActive: true,
        createdAt: DateTime.utc(2026),
        deletedAt: deletedAt,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    habitsDao = HabitsDao(db);
    completionDao = HabitCompletionDao(db);
    currentUser = null;
    remote = FakeSyncRemoteApi(currentUserId: () => currentUser);
    connect = FakeAppConnect();
    authChanges = StreamController<String?>.broadcast();
    sync = SyncService(
      database: db,
      remoteApi: remote,
      appConnect: connect,
      userIdChanges: authChanges.stream,
      currentUserId: () => currentUser,
      // Long enough that only explicit syncNow() calls run during a test.
      debounce: const Duration(minutes: 10),
      pageSize: 2,
    )..start();
  });

  tearDown(() async {
    await sync.dispose();
    await authChanges.close();
    await db.close();
  });

  group('push', () {
    test('offline writes are uploaded on the next sync and then marked synced', () async {
      await signIn(alice);
      connect.goOffline();
      await addLocalHabit('h1');
      await completionDao.setCompleted('h1', day, completed: true);

      expect(await sync.syncNow(), isFalse, reason: 'no connection');
      expect(remote.habitsOf(alice), isEmpty);
      expect(await sync.pendingChangesCount(), 2);

      connect.goOnline();
      expect(await sync.syncNow(), isTrue);

      expect(remote.habitsOf(alice).keys, ['h1']);
      expect(remote.completionsOf(alice).values.single.completedOn, '2026-10-09');
      expect(await sync.pendingChangesCount(), 0);
    });

    test('regaining connectivity triggers a sync without user action', () async {
      await signIn(alice);
      connect.goOffline();
      await addLocalHabit('h1');
      await sync.syncNow();

      connect.goOnline();
      await pumpEventQueue();
      await sync.syncNow(); // joins the run started by the connectivity event

      expect(remote.habitsOf(alice).keys, ['h1']);
    });

    test('an interrupted sync resumes where it stopped', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await completionDao.setCompleted('h1', day, completed: true);
      remote.failNextCompletionUpsert = const SyncNetworkException('offline');

      expect(await sync.syncNow(), isFalse);
      expect(remote.habitsOf(alice), hasLength(1), reason: 'habits were pushed before the failure');
      expect(await completionDao.countPending(), 1);

      expect(await sync.syncNow(), isTrue);
      expect(remote.completionsOf(alice), hasLength(1));
      expect(await sync.pendingChangesCount(), 0);
    });

    test('a retry after a lost response does not create a duplicate completion', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await completionDao.setCompleted('h1', day, completed: true);
      remote.loseNextCompletionResponse = true;

      expect(await sync.syncNow(), isFalse);
      expect(await completionDao.countPending(), 1, reason: 'client cannot know the server applied it');

      expect(await sync.syncNow(), isTrue);
      expect(remote.completionsOf(alice), hasLength(1));
    });

    test('the same day completed on two devices converges to one record', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await sync.syncNow();
      // Another device completed the same day; it derives the same id.
      remote.serverPutCompletion(
        alice,
        RemoteCompletion(id: HabitCompletionDao.completionId('h1', day), habitId: 'h1', completedOn: '2026-10-09'),
      );
      await completionDao.setCompleted('h1', day, completed: true);

      expect(await sync.syncNow(), isTrue);
      expect(remote.completionsOf(alice), hasLength(1));
      expect(await completionDao.getAllCompletions(), hasLength(1));
    });

    test('a row rejected by the server does not block the others and is not dropped', () async {
      await signIn(alice);
      await addLocalHabit('bad');
      await addLocalHabit('good');
      remote.rejectedHabitIds.add('bad');

      expect(await sync.syncNow(), isTrue);
      expect(remote.habitsOf(alice).keys, ['good']);
      expect((await habitsDao.getPending()).map((h) => h.id), ['bad']);
    });

    test('an edit made while the push is in flight stays pending', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      final pushed = (await habitsDao.getPending()).single;
      await habitsDao.updateLocal('h1', title: 'Edited meanwhile');

      await habitsDao.markPushed(pushed);

      expect((await habitsDao.getPending()).single.title, 'Edited meanwhile');
    });

    test('a local deletion reaches the server and the tombstone is then removed locally', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await completionDao.setCompleted('h1', day, completed: true);
      await sync.syncNow();

      await habitsDao.markDeleted('h1');
      expect(await habitsDao.getAllHabits(), isEmpty, reason: 'hidden immediately');
      expect(await sync.syncNow(), isTrue);

      expect(remote.habitsOf(alice)['h1']!.deletedAt, isNotNull);
      expect(await db.select(db.habits).get(), isEmpty);
      expect(await db.select(db.habitCompletions).get(), isEmpty);
    });

    test('un-marking a day is propagated as a completion tombstone', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await completionDao.setCompleted('h1', day, completed: true);
      await sync.syncNow();

      await completionDao.setCompleted('h1', day, completed: false);
      await sync.syncNow();

      expect(remote.completionsOf(alice).values.single.deletedAt, isNotNull);
      expect(await completionDao.getAllCompletions(), isEmpty);
    });
  });

  group('pull', () {
    test('downloads changes from other devices across several pages', () async {
      await signIn(alice);
      for (var i = 0; i < 5; i++) {
        remote.serverPutHabit(alice, remoteHabit('r$i'));
      }

      expect(await sync.syncNow(), isTrue);

      expect((await habitsDao.getAllHabits()).map((h) => h.id), unorderedEquals(['r0', 'r1', 'r2', 'r3', 'r4']));
      expect(await sync.pendingChangesCount(), 0, reason: 'downloaded rows are not re-uploaded');
      expect(await SyncStateDao(db).read(SyncService.habitCursorKey), isNotNull);
    });

    test('applies remote deletions, including the habit completions', () async {
      await signIn(alice);
      remote
        ..serverPutHabit(alice, remoteHabit('r1'))
        ..serverPutCompletion(alice, const RemoteCompletion(id: 'c1', habitId: 'r1', completedOn: '2026-10-08'));
      await sync.syncNow();
      expect(await completionDao.getAllCompletions(), hasLength(1));

      remote.serverPutHabit(alice, remoteHabit('r1', deletedAt: DateTime.utc(2026, 10, 9)));
      await sync.syncNow();

      expect(await habitsDao.getAllHabits(), isEmpty);
      expect(await db.select(db.habitCompletions).get(), isEmpty);
    });

    test('a pending local edit wins over an older server version', () async {
      await signIn(alice);
      remote.serverPutHabit(alice, remoteHabit('r1', title: 'Server'));
      await sync.syncNow();

      await habitsDao.updateLocal('r1', title: 'Offline edit');
      await sync.syncNow();

      expect(remote.habitsOf(alice)['r1']!.title, 'Offline edit');
      expect((await habitsDao.getHabitById('r1'))!.title, 'Offline edit');
    });

    test('a deletion on another device wins over a stale offline edit', () async {
      await signIn(alice);
      remote.serverPutHabit(alice, remoteHabit('r1'));
      await sync.syncNow();
      remote.serverPutHabit(alice, remoteHabit('r1', deletedAt: DateTime.utc(2026, 10, 9)));

      await habitsDao.updateLocal('r1', title: 'Stale edit');
      await sync.syncNow();

      expect(remote.habitsOf(alice)['r1']!.deletedAt, isNotNull);
      expect(await habitsDao.getAllHabits(), isEmpty);
    });
  });

  group('schedules', () {
    test('an offline schedule change with a streak reset is uploaded together, history intact', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await completionDao.setCompleted('h1', day.addDays(-1), completed: true);
      await completionDao.setCompleted('h1', day, completed: true);
      await sync.syncNow();

      connect.goOffline();
      await habitsDao.updateLocal(
        'h1',
        schedule: (type: 'weekly_target', weeklyTarget: 3, days: null),
        streakResetOn: day.toString(),
      );
      expect(await sync.syncNow(), isFalse);
      expect(await sync.pendingChangesCount(), 1, reason: 'only the habit row changed');
      expect(remote.habitsOf(alice)['h1']!.scheduleType, 'daily', reason: 'nothing is sent while offline');

      connect.goOnline();
      expect(await sync.syncNow(), isTrue);
      final pushed = remote.habitsOf(alice)['h1']!;
      expect((pushed.scheduleType, pushed.weeklyTarget, pushed.scheduleDays, pushed.streakResetOn),
          ('weekly_target', 3, null, '2026-10-09'));
      expect(remote.completionsOf(alice), hasLength(2), reason: 'a streak reset never deletes completions');
      expect(await completionDao.getAllCompletions(), hasLength(2));
    });

    test('switching type clears the parameters of the old one', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await habitsDao.updateLocal('h1', schedule: (type: 'weekdays', weeklyTarget: null, days: 21));
      await habitsDao.updateLocal('h1', schedule: (type: 'weekly_target', weeklyTarget: 2, days: null));
      await sync.syncNow();

      final pushed = remote.habitsOf(alice)['h1']!;
      expect((pushed.scheduleType, pushed.weeklyTarget, pushed.scheduleDays), ('weekly_target', 2, null));
    });

    test('a schedule and reset day from another device are applied locally', () async {
      await signIn(alice);
      remote.serverPutHabit(
        alice,
        RemoteHabit(
          id: 'r1',
          categoryId: 'sport',
          title: 'Gym',
          description: null,
          icon: '🏋️',
          steps: 0,
          isActive: true,
          createdAt: DateTime.utc(2026),
          scheduleType: 'weekdays',
          scheduleDays: 21,
          streakResetOn: '2026-10-05',
        ),
      );
      await sync.syncNow();

      final local = (await habitsDao.getHabitById('r1'))!;
      expect((local.scheduleType, local.weeklyTarget, local.scheduleDays, local.streakResetOn),
          ('weekdays', null, 21, '2026-10-05'));
      expect(await sync.pendingChangesCount(), 0);
    });

    test('older rows without schedule columns read as daily', () {
      final habit = RemoteHabit.fromJson({
        'id': 'h1',
        'category_id': 'sport',
        'title': 'Old',
        'description': null,
        'icon': '🏃',
        'steps': 0,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'deleted_at': null,
      });
      expect((habit.scheduleType, habit.weeklyTarget, habit.scheduleDays, habit.streakResetOn),
          ('daily', null, null, null));
    });

    test('schedule fields survive the wire format', () {
      final habit = RemoteHabit(
        id: 'h1',
        categoryId: 'sport',
        title: 'Run',
        description: null,
        icon: '🏃',
        steps: 0,
        isActive: true,
        createdAt: DateTime.utc(2026),
        scheduleType: 'weekly_target',
        weeklyTarget: 4,
        streakResetOn: '2026-10-09',
      );
      final json = habit.toJson();
      expect(json, containsPair('schedule_type', 'weekly_target'));
      expect(json, containsPair('weekly_target', 4));
      expect(json, containsPair('schedule_days', null));
      expect(json, containsPair('streak_reset_on', '2026-10-09'));
      final back = RemoteHabit.fromJson({...json, 'updated_at': '2026-10-09T00:00:00Z'});
      expect((back.scheduleType, back.weeklyTarget, back.scheduleDays, back.streakResetOn),
          ('weekly_target', 4, null, '2026-10-09'));
      for (final column in ['schedule_type', 'weekly_target', 'schedule_days', 'streak_reset_on']) {
        expect(RemoteHabit.columns, contains(column));
      }
    });
  });

  group('accounts', () {
    test('data created before sign-in is adopted by the first account', () async {
      await addLocalHabit('legacy');

      await signIn(alice);
      await sync.syncNow();

      expect(remote.habitsOf(alice).keys, ['legacy']);
    });

    test('switching accounts removes the previous user data without uploading it', () async {
      await signIn(alice);
      connect.goOffline();
      await addLocalHabit('alice-private');

      await signIn(null);
      await signIn(bob);
      connect.goOnline();
      await sync.syncNow();

      expect(await habitsDao.getAllHabits(), isEmpty);
      expect(remote.habitsOf(bob), isEmpty);
      expect(remote.habitsOf(alice), isEmpty);
    });

    test('the same user signing back in keeps the local data', () async {
      await signIn(alice);
      connect.goOffline();
      await addLocalHabit('h1');

      await signIn(null);
      await signIn(alice);

      expect(await habitsDao.getAllHabits(), hasLength(1));
      expect(await sync.pendingChangesCount(), 1);
    });

    test('a response fetched for a previous session is discarded', () async {
      await signIn(alice);
      remote
        ..serverPutHabit(alice, remoteHabit('r1'))
        ..beforeFetch = () => currentUser = bob;

      expect(await sync.syncNow(), isFalse);
      expect(await habitsDao.getAllHabits(), isEmpty);
    });

    test('clearLocalData removes habits, completions and sync state', () async {
      await signIn(alice);
      await addLocalHabit('h1');
      await completionDao.setCompleted('h1', day, completed: true);

      await sync.clearLocalData();

      expect(await db.select(db.habits).get(), isEmpty);
      expect(await db.select(db.habitCompletions).get(), isEmpty);
      expect(await db.select(db.syncState).get(), isEmpty);
      expect(await sync.syncNow(), isFalse, reason: 'nothing may be pulled back before sign-out finishes');
    });
  });

  test('an expired session pauses sync without losing data', () async {
    await signIn(alice);
    await addLocalHabit('h1');
    remote.failNextHabitUpsert = const SyncAuthException('PGRST301: JWT expired');

    expect(await sync.syncNow(), isFalse);
    expect(await sync.pendingChangesCount(), 1);
    expect(await sync.syncNow(), isTrue);
  });

  test('pending rows can be queried with their tombstones', () async {
    await addLocalHabit('h1');
    await habitsDao.markDeleted('h1');
    final pending = await habitsDao.getPending();
    expect(pending.single.deletedAt, isNotNull);
    expect(await (db.select(db.habits)..where((t) => t.id.equals('h1'))).getSingleOrNull(), isNotNull);
  });
}
