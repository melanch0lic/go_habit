import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/habits_dao.dart';
import 'package:go_habit/core/database/drift_database.dart' hide Habit;
import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/feature/habits/data/data_sources/local/local_habit_data_source.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/data/repositories/habit_repository_implementation.dart';

class _RecordingScheduler implements SyncScheduler {
  int requests = 0;

  @override
  void requestSync() => requests++;
}

void main() {
  late AppDatabase db;
  late HabitsDao dao;
  late _RecordingScheduler scheduler;
  late HabitsRepositoryImplementation repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = HabitsDao(db);
    scheduler = _RecordingScheduler();
    repository = HabitsRepositoryImplementation(DriftHabitDataSource(dao), scheduler);
  });

  tearDown(() => db.close());

  final habit = Habit(id: 'h1', title: 'Read', description: '20 pages', categoryId: 'education', icon: '📚', steps: 2);

  test('writes are local-first: visible immediately, queued for upload, sync requested', () async {
    await repository.addHabit(habit);

    final stored = (await repository.getHabits()).single;
    expect(stored.title, 'Read');
    expect(stored.icon, '📚');
    expect(stored.steps, 2);
    expect((await dao.getPending()).single.id, 'h1');
    expect(scheduler.requests, 1);
  });

  test('updates keep untouched fields and are queued', () async {
    await repository.addHabit(habit);
    await repository.updateHabit(habit.copyWith(isActive: false));

    final stored = (await repository.getHabits()).single;
    expect(stored.isActive, isFalse);
    expect(stored.description, '20 pages');
    expect((await dao.getPending()).single.localVersion, 2);
    expect(scheduler.requests, 2);
  });

  test('updating a habit that does not exist fails instead of silently doing nothing', () async {
    expect(() => repository.updateHabit(habit), throwsStateError);
  });

  test('deleted habits disappear from reads and the stream at once', () async {
    await repository.addHabit(habit);
    final emissions = repository.watchHabits().map((list) => list.length);
    final expectation = expectLater(emissions, emitsInOrder([1, 0]));

    await Future<void>.delayed(Duration.zero);
    await repository.deleteHabit('h1');

    await expectation;
    expect(await repository.getHabits(), isEmpty);
    expect((await dao.getPending()).single.deletedAt, isNotNull, reason: 'tombstone waits for upload');
  });
}
