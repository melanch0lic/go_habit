import 'package:drift/drift.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/database/tables/habit_completions.dart';
import 'package:go_habit/core/database/tables/habits.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:uuid/uuid.dart';

part 'habit_completion_dao.g.dart';

@DriftAccessor(tables: [HabitCompletions, Habits])
class HabitCompletionDao extends DatabaseAccessor<AppDatabase> with _$HabitCompletionDaoMixin {
  HabitCompletionDao(super.db);

  /// Namespace for [completionId]. Never change it: ids must match across devices and versions.
  static const _idNamespace = '5b0c6a8e-3f5d-4a8b-9c1e-0a7f2d4e6b19';

  /// The same habit and day always yield the same id, on every device, so retries
  /// and concurrent offline completions converge on one record.
  static String completionId(String habitId, CalendarDay day) =>
      const Uuid().v5(_idNamespace, '$habitId/${day.toIsoString()}');

  /// Completions of habits that are not deleted.
  Stream<List<HabitCompletion>> watchCompletions() {
    final query = select(habitCompletions).join([
      innerJoin(habits, habits.id.equalsExp(habitCompletions.habitId), useColumns: false),
    ])
      ..where(habitCompletions.deletedAt.isNull() & habits.deletedAt.isNull())
      ..orderBy([OrderingTerm(expression: habitCompletions.completedOn)]);
    return query.map((row) => row.readTable(habitCompletions)).watch();
  }

  Future<List<HabitCompletion>> getAllCompletions() =>
      (select(habitCompletions)..where((t) => t.deletedAt.isNull())).get();

  /// Marks or un-marks [day] for a habit and queues the change for upload.
  Future<void> setCompleted(String habitId, CalendarDay day, {required bool completed}) {
    final now = DateTime.now();
    final deletedAt = completed ? null : now;
    return into(habitCompletions).insert(
      HabitCompletionsCompanion.insert(
        id: completionId(habitId, day),
        habitId: habitId,
        completedOn: day.toIsoString(),
        updatedAt: Value(now),
        deletedAt: Value(deletedAt),
        isPendingSync: const Value(true),
        localVersion: const Value(1),
      ),
      onConflict: DoUpdate(
        (old) => HabitCompletionsCompanion.custom(
          deletedAt: Variable(deletedAt),
          updatedAt: Variable(now),
          isPendingSync: const Constant(true),
          localVersion: old.localVersion + const Constant(1),
        ),
        target: [habitCompletions.habitId, habitCompletions.completedOn],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Synchronization
  // ---------------------------------------------------------------------------

  Future<List<HabitCompletion>> getPending() =>
      (select(habitCompletions)..where((t) => t.isPendingSync.equals(true))).get();

  /// Called after [completion] was accepted by the server; see `HabitsDao.markPushed`.
  Future<void> markPushed(HabitCompletion completion) async {
    Expression<bool> unchanged($HabitCompletionsTable t) =>
        t.id.equals(completion.id) & t.localVersion.equals(completion.localVersion);

    if (completion.deletedAt != null) {
      await (delete(habitCompletions)..where(unchanged)).go();
    } else {
      await (update(habitCompletions)..where(unchanged))
          .write(const HabitCompletionsCompanion(isPendingSync: Value(false)));
    }
  }

  /// Applies server rows, skipping rows with unpushed local changes.
  Future<void> applyRemote(List<HabitCompletionsCompanion> rows, {required Set<String> deletedIds}) =>
      transaction(() async {
        final pendingIds = (await getPending()).map((c) => c.id).toSet();
        final removable = deletedIds.difference(pendingIds);
        if (removable.isNotEmpty) {
          await (delete(habitCompletions)..where((t) => t.id.isIn(removable))).go();
        }
        for (final row in rows) {
          if (pendingIds.contains(row.id.value)) continue;
          // A different local id for the same (habit, day) cannot come from this app
          // version, but must not block the server row either.
          await (delete(habitCompletions)
                ..where((t) =>
                    t.habitId.equals(row.habitId.value) &
                    t.completedOn.equals(row.completedOn.value) &
                    t.id.equals(row.id.value).not()))
              .go();
          final synced = row.copyWith(isPendingSync: const Value(false), deletedAt: const Value(null));
          await into(habitCompletions).insert(synced, onConflict: DoUpdate((_) => synced));
        }
      });

  Future<int> countPending() async {
    final count = habitCompletions.id.count();
    final query = selectOnly(habitCompletions)
      ..addColumns([count])
      ..where(habitCompletions.isPendingSync.equals(true));
    return (await query.map((row) => row.read(count)).getSingle()) ?? 0;
  }
}
