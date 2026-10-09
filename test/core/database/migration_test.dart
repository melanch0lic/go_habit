// Calendar dates are spelled out in full for readability.
// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/database/dao/habit_completion_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/utils/calendar_day.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;

/// Regenerate helpers after a schema change:
/// `dart run drift_dev schema dump lib/core/database/drift_database.dart drift_schemas/drift_schema_vN.json`
/// `dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/`
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  int seconds(DateTime dateTime) => dateTime.millisecondsSinceEpoch ~/ 1000;

  test('a fresh install matches the latest schema snapshot', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('upgrading from v1 keeps habits and completion history and queues them for upload', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    final created = seconds(DateTime(2026, 9, 1));

    v1.HabitsCompanion habit(String id,
            {DateTime? lastCompleted, String syncStatus = 'synced', bool pending = false}) =>
        v1.HabitsCompanion.insert(
          id: id,
          title: 'Habit $id',
          categoryId: 'health',
          createdAt: created,
          updatedAt: created,
          lastTimeCompleted: Value(lastCompleted == null ? null : seconds(lastCompleted)),
          syncStatus: Value(syncStatus),
          isPendingSync: Value(pending ? 1 : 0), // v1 helpers expose raw SQL types
          steps: const Value(3),
          icon: const Value('💧'),
        );

    await old.batch((batch) {
      batch
        ..insert(
            old.habitCategories, v1.HabitCategoriesCompanion.insert(id: 'health', name: 'Здоровье', color: '#FF6B6B'))
        ..insertAll(old.habits, [
          // Completed late in the evening: must count for that calendar day.
          habit('a', lastCompleted: DateTime(2026, 10, 1, 23, 50)),
          // Deleted offline, deletion not yet synced.
          habit('b', syncStatus: 'delete', pending: true),
          // "Undo" used to write this sentinel date.
          habit('c', lastCompleted: DateTime(2023, 3, 31)),
        ])
        ..insertAll(old.habitCompletions, [
          v1.HabitCompletionsCompanion.insert(habitId: 'a', dateComplete: seconds(DateTime(2026, 9, 30, 8))),
          // Same day as habit a's last_time_completed: must not duplicate.
          v1.HabitCompletionsCompanion.insert(habitId: 'a', dateComplete: seconds(DateTime(2026, 10, 1))),
          v1.HabitCompletionsCompanion.insert(habitId: 'c', dateComplete: seconds(DateTime(2023, 3, 31))),
          // References a habit that does not exist locally.
          v1.HabitCompletionsCompanion.insert(habitId: 'gone', dateComplete: seconds(DateTime(2026, 9, 1))),
        ])
        ..insert(
          old.habitStreaks,
          v1.HabitStreaksCompanion.insert(habitId: 'a', currentStreak: 2, lastUpdate: created),
        );
    });
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final habits = {for (final h in await db.select(db.habits).get()) h.id: h};
    expect(habits.keys, unorderedEquals(['a', 'b', 'c']));
    expect(habits['a']!.steps, 3);
    expect(habits['a']!.icon, '💧');
    expect(habits['a']!.createdAt, DateTime(2026, 9, 1));
    expect(habits.values.every((h) => h.isPendingSync), isTrue, reason: 'everything goes to the new backend');
    expect(habits['b']!.deletedAt, isNotNull);
    expect(habits['a']!.deletedAt, isNull);

    final completions = await db.select(db.habitCompletions).get();
    expect(
      completions.map((c) => (c.habitId, c.completedOn)),
      unorderedEquals([('a', '2026-09-30'), ('a', '2026-10-01')]),
    );
    expect(completions.every((c) => c.isPendingSync), isTrue);
    expect(
      completions.map((c) => c.id),
      contains(HabitCompletionDao.completionId('a', CalendarDay(2026, 10, 1))),
      reason: 'ids are deterministic so other devices produce the same record',
    );

    final categories = await db.select(db.habitCategories).get();
    expect(categories.single.sortOrder, 0);
    expect(await db.select(db.syncState).get(), isEmpty, reason: 'no owner yet: adopted at first sign-in');

    await db.close();
  });
}
