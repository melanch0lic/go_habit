import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:go_habit/core/database/dao/habit_completion_dao.dart';
import 'package:go_habit/core/database/dao/habits_dao.dart';
import 'package:go_habit/core/database/tables/community_cache.dart';
import 'package:go_habit/core/database/tables/habit_categories.dart';
import 'package:go_habit/core/database/tables/habit_completions.dart';
import 'package:go_habit/core/database/tables/habits.dart';
import 'package:go_habit/core/database/tables/sync_state.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:path_provider/path_provider.dart';

part 'drift_database.g.dart';

@DriftDatabase(
  tables: [Habits, HabitCategories, HabitCompletions, SyncState, HabitTemplates, CommunityMemberships],
  daos: [HabitsDao],
)
class AppDatabase extends _$AppDatabase {
  /// [executor] is for tests; the app uses the on-device database.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Schema history (snapshots in `drift_schemas/`):
  /// 1 — initial release.
  /// 2 — completions keyed by calendar day, tombstones, per-row sync versions,
  ///     sync metadata table; `habit_streaks`, `habits.sync_status` and
  ///     `habits.last_time_completed` removed.
  /// 3 — offline caches of the habit catalog and community memberships.
  /// 4 — community memberships no longer link a personal habit.
  /// 5 — community memberships link the ranked habit again.
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) await _migrateFrom1To2(m);
        if (from < 3) {
          await m.createTable(habitTemplates);
          await m.createTable(communityMemberships);
        }
        // v3 already has `habit_id` (v4 removed it), so only v4 needs it added back.
        if (from == 4) await m.addColumn(communityMemberships, communityMemberships.habitId);
      },
    );
  }

  /// Keeps every habit and completion. The previous backend no longer exists, so all
  /// local data is queued for upload to the new one and adopted by the first account
  /// that signs in on this device.
  Future<void> _migrateFrom1To2(Migrator m) async {
    // v1 stored DateTime as unix seconds.
    DateTime fromSeconds(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    // v1 wrote this date to mean "not completed" when a completion was undone.
    final undoSentinel = CalendarDay(2023, 3, 31);

    final legacyHabits = await customSelect(
      'SELECT id, sync_status, is_pending_sync, last_time_completed FROM habits',
    ).get();
    final legacyCompletions = await customSelect('SELECT habit_id, date_complete FROM habit_completions').get();

    final habitIds = legacyHabits.map((row) => row.read<String>('id')).toSet();
    final pendingDeletes = legacyHabits
        .where((row) => row.read<String>('sync_status') == 'delete' && row.read<bool>('is_pending_sync'))
        .map((row) => row.read<String>('id'))
        .toList();

    final completedDays = <(String, CalendarDay)>{};
    for (final row in legacyHabits) {
      final seconds = row.readNullable<int>('last_time_completed');
      if (seconds != null) completedDays.add((row.read<String>('id'), CalendarDay.fromDateTime(fromSeconds(seconds))));
    }
    for (final row in legacyCompletions) {
      completedDays
          .add((row.read<String>('habit_id'), CalendarDay.fromDateTime(fromSeconds(row.read<int>('date_complete')))));
    }
    completedDays.removeWhere((entry) => entry.$2 == undoSentinel || !habitIds.contains(entry.$1));

    await m.alterTable(
      TableMigration(
        habits,
        newColumns: [habits.deletedAt, habits.localVersion],
        columnTransformer: {habits.isPendingSync: const Constant(true)},
      ),
    );
    await update(habits).write(const HabitsCompanion(localVersion: Value(1)));
    if (pendingDeletes.isNotEmpty) {
      await (update(habits)..where((t) => t.id.isIn(pendingDeletes)))
          .write(HabitsCompanion(deletedAt: Value(DateTime.now())));
    }

    await m.deleteTable('habit_streaks');
    await m.deleteTable('habit_completions');
    await m.createTable(habitCompletions);
    await m.createTable(syncState);
    await m.addColumn(habitCategories, habitCategories.sortOrder);

    await batch((batch) {
      batch.insertAll(habitCompletions, [
        for (final (habitId, day) in completedDays)
          HabitCompletionsCompanion.insert(
            id: HabitCompletionDao.completionId(habitId, day),
            habitId: habitId,
            completedOn: day.toIsoString(),
            isPendingSync: const Value(true),
            localVersion: const Value(1),
          ),
      ]);
    });
  }

  /// Removes everything that belongs to the signed-in user. Categories and the habit
  /// catalog are shared reference data and are kept.
  Future<void> clearUserData() => transaction(() async {
        await delete(communityMemberships).go();
        await delete(habitCompletions).go();
        await delete(habits).go();
        await delete(syncState).go();
      });

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'drift_database',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
