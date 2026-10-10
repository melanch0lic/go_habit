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
import '../../generated_migrations/schema_v2.dart' as v2;
import '../../generated_migrations/schema_v3.dart' as v3;
import '../../generated_migrations/schema_v4.dart' as v4;
import '../../generated_migrations/schema_v5.dart' as v5;
import '../../generated_migrations/schema_v6.dart' as v6;
import '../../generated_migrations/schema_v7.dart' as v7;
import '../../generated_migrations/schema_v8.dart' as v8;

/// Regenerate helpers after a schema change:
/// `dart run drift_dev schema dump lib/core/database/drift_database.dart drift_schemas/drift_schema_vN.json`
/// `dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/`
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  int seconds(DateTime dateTime) => dateTime.millisecondsSinceEpoch ~/ 1000;

  test('a fresh install matches the latest schema snapshot', () async {
    final schema = await verifier.schemaAt(9);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);
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
    await verifier.migrateAndValidate(db, 9);

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

  test('upgrading from v2 adds the community caches and keeps habits and completions', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old
        .into(old.habitCategories)
        .insert(v2.HabitCategoriesCompanion.insert(id: 'health', name: 'H', color: '#FF0000'));
    await old.into(old.habits).insert(
          v2.HabitsCompanion.insert(
            id: 'h1',
            title: 'Walk',
            categoryId: 'health',
            createdAt: seconds(DateTime(2026, 9, 1)),
            updatedAt: seconds(DateTime(2026, 9, 1)),
            isPendingSync: const Value(1),
          ),
        );
    await old.into(old.habitCompletions).insert(
          v2.HabitCompletionsCompanion.insert(
            id: 'c1',
            habitId: 'h1',
            completedOn: '2026-10-05',
            updatedAt: seconds(DateTime(2026, 10, 5)),
          ),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final habit = await (db.select(db.habits)..where((t) => t.id.equals('h1'))).getSingle();
    expect(habit.isPendingSync, isTrue, reason: 'pending uploads survive the upgrade');
    expect(await db.select(db.habitCompletions).get(), hasLength(1));
    expect(await db.select(db.habitTemplates).get(), isEmpty);
    expect(await db.select(db.communityMemberships).get(), isEmpty);
    await db.close();
  });

  test('upgrading from v3 keeps cached memberships and their ranked habit', () async {
    final schema = await verifier.schemaAt(3);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await old.into(old.communityMemberships).insert(
          v3.CommunityMembershipsCompanion.insert(
              templateId: 'reading', habitId: const Value('h1'), joinedOn: '2026-10-09'),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final membership = (await db.select(db.communityMemberships).get()).single;
    expect(membership.templateId, 'reading');
    expect(membership.habitId, 'h1');
    expect(membership.joinedOn, '2026-10-09');
    await db.close();
  });

  test('upgrading from v4 adds the ranked habit column back and keeps memberships', () async {
    final schema = await verifier.schemaAt(4);
    final old = v4.DatabaseAtV4(schema.newConnection());
    await old
        .into(old.communityMemberships)
        .insert(v4.CommunityMembershipsCompanion.insert(templateId: 'reading', joinedOn: '2026-10-09'));
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final membership = (await db.select(db.communityMemberships).get()).single;
    expect(membership.templateId, 'reading');
    expect(membership.habitId, isNull);
    await db.close();
  });

  test('upgrading from v5 adds the social cache and keeps everything else', () async {
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    await old.into(old.communityMemberships).insert(
          v5.CommunityMembershipsCompanion.insert(
              templateId: 'reading', habitId: const Value('h1'), joinedOn: '2026-10-09'),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    expect((await db.select(db.communityMemberships).get()).single.habitId, 'h1');
    expect(await db.select(db.socialCache).get(), isEmpty);
    await db.close();
  });

  test('upgrading from v6 makes every existing habit daily and keeps its data', () async {
    final schema = await verifier.schemaAt(6);
    final old = v6.DatabaseAtV6(schema.newConnection());
    final created = seconds(DateTime(2026, 9, 1));
    await old
        .into(old.habitCategories)
        .insert(v6.HabitCategoriesCompanion.insert(id: 'health', name: 'H', color: '#FF0000'));
    await old.into(old.habits).insert(
          v6.HabitsCompanion.insert(
            id: 'h1',
            title: 'Walk',
            categoryId: 'health',
            createdAt: created,
            updatedAt: created,
            isPendingSync: const Value(1),
          ),
        );
    await old.into(old.habitCompletions).insert(
          v6.HabitCompletionsCompanion.insert(id: 'c1', habitId: 'h1', completedOn: '2026-10-05', updatedAt: created),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final habit = (await db.select(db.habits).get()).single;
    expect(habit.scheduleType, 'daily');
    expect(habit.weeklyTarget, isNull);
    expect(habit.streakResetOn, isNull);
    expect(habit.isPendingSync, isTrue, reason: 'pending uploads survive');
    expect(await db.select(db.habitCompletions).get(), hasLength(1), reason: 'history is kept');
    await db.close();
  });

  test('upgrading from v7 adds the recommended schedule to the catalog cache and keeps memberships', () async {
    final schema = await verifier.schemaAt(7);
    final old = v7.DatabaseAtV7(schema.newConnection());
    await old.into(old.habitTemplates).insert(
          v7.HabitTemplatesCompanion.insert(
            id: 'reading',
            categoryId: 'education',
            title: '{"ru": "Чтение", "en": "Reading"}',
            description: '{"ru": "", "en": ""}',
            icon: '📚',
          ),
        );
    await old
        .into(old.communityMemberships)
        .insert(v7.CommunityMembershipsCompanion.insert(templateId: 'reading', joinedOn: '2026-10-01'));
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final template = (await db.select(db.habitTemplates).get()).single;
    expect((template.scheduleType, template.weeklyTarget, template.scheduleDays), ('daily', null, null));
    expect((await db.select(db.communityMemberships).get()).single.templateId, 'reading');
    await db.close();
  });

  test('upgrading from v8 adds empty reminder and history tables and keeps habits', () async {
    final schema = await verifier.schemaAt(8);
    final old = v8.DatabaseAtV8(schema.newConnection());
    final created = seconds(DateTime(2026, 9, 1));
    await old
        .into(old.habitCategories)
        .insert(v8.HabitCategoriesCompanion.insert(id: 'health', name: 'H', color: '#FF0000'));
    await old.into(old.habits).insert(
          v8.HabitsCompanion.insert(
              id: 'h1', title: 'Walk', categoryId: 'health', createdAt: created, updatedAt: created),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);
    expect((await db.select(db.habits).get()).single.id, 'h1');
    expect(await db.select(db.habitReminders).get(), isEmpty);
    expect(await db.select(db.notificationHistory).get(), isEmpty);
    await db.close();
  });
}
