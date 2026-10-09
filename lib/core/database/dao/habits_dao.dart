import 'package:drift/drift.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/database/tables/habit_completions.dart';
import 'package:go_habit/core/database/tables/habits.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [Habits, HabitCompletions])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  SimpleSelectStatement<$HabitsTable, Habit> _visible() => select(habits)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);

  Future<List<Habit>> getAllHabits() => _visible().get();

  Stream<List<Habit>> watchHabits() => _visible().watch();

  Future<Habit?> getHabitById(String id) =>
      (select(habits)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Inserts a habit created on this device; it is queued for upload.
  Future<void> insertLocal(HabitsCompanion entry) => into(habits).insert(
        entry.copyWith(
          isPendingSync: const Value(true),
          localVersion: const Value(1),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Applies a local edit and queues it for upload. Returns the number of updated rows.
  Future<int> updateLocal(
    String habitId, {
    String? title,
    String? description,
    String? categoryId,
    int? steps,
    bool? isActive,
    String? icon,
  }) {
    return (update(habits)..where((t) => t.id.equals(habitId) & t.deletedAt.isNull())).write(
      HabitsCompanion.custom(
        title: title == null ? null : Variable(title),
        description: description == null ? null : Variable(description),
        categoryId: categoryId == null ? null : Variable(categoryId),
        steps: steps == null ? null : Variable(steps),
        isActive: isActive == null ? null : Variable(isActive),
        icon: icon == null ? null : Variable(icon),
        updatedAt: Variable(DateTime.now()),
        isPendingSync: const Constant(true),
        localVersion: habits.localVersion + const Constant(1),
      ),
    );
  }

  /// Marks a habit as deleted. The row stays as a tombstone until the deletion is pushed.
  Future<int> markDeleted(String habitId) {
    final now = DateTime.now();
    return (update(habits)..where((t) => t.id.equals(habitId) & t.deletedAt.isNull())).write(
      HabitsCompanion.custom(
        deletedAt: Variable(now),
        updatedAt: Variable(now),
        isPendingSync: const Constant(true),
        localVersion: habits.localVersion + const Constant(1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Synchronization
  // ---------------------------------------------------------------------------

  /// All rows with unpushed changes, including deletion tombstones.
  Future<List<Habit>> getPending() => (select(habits)..where((t) => t.isPendingSync.equals(true))).get();

  /// Called after [habit] was accepted by the server. If the row changed meanwhile
  /// (newer [Habit.localVersion]) it stays pending. Pushed tombstones are removed.
  Future<void> markPushed(Habit habit) => transaction(() async {
        Expression<bool> unchanged($HabitsTable t) => t.id.equals(habit.id) & t.localVersion.equals(habit.localVersion);

        if (habit.deletedAt != null) {
          final deleted = await (delete(habits)..where(unchanged)).go();
          if (deleted > 0) await _deleteCompletionsOf(habit.id);
        } else {
          await (update(habits)..where(unchanged)).write(const HabitsCompanion(isPendingSync: Value(false)));
        }
      });

  /// Applies server rows. Rows with unpushed local changes are left untouched: they are
  /// pushed on the next run and the server decides the outcome (see docs/SYNC.md).
  Future<void> applyRemote(List<HabitsCompanion> rows, {required Set<String> deletedIds}) => transaction(() async {
        final pendingIds = await _pendingIds();
        for (final id in deletedIds.difference(pendingIds)) {
          await (delete(habits)..where((t) => t.id.equals(id))).go();
          await _deleteCompletionsOf(id);
        }
        for (final row in rows) {
          if (pendingIds.contains(row.id.value)) continue;
          await into(habits).insert(
            row.copyWith(isPendingSync: const Value(false), deletedAt: const Value(null)),
            onConflict: DoUpdate((_) => row.copyWith(isPendingSync: const Value(false), deletedAt: const Value(null))),
          );
        }
      });

  Future<Set<String>> _pendingIds() async {
    final query = selectOnly(habits)
      ..addColumns([habits.id])
      ..where(habits.isPendingSync.equals(true));
    return (await query.map((row) => row.read(habits.id)!).get()).toSet();
  }

  Future<void> _deleteCompletionsOf(String habitId) =>
      (delete(habitCompletions)..where((t) => t.habitId.equals(habitId))).go();

  Future<int> countPending() async {
    final count = habits.id.count();
    final query = selectOnly(habits)
      ..addColumns([count])
      ..where(habits.isPendingSync.equals(true));
    return (await query.map((row) => row.read(count)).getSingle()) ?? 0;
  }
}
