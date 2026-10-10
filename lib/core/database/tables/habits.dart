import 'package:drift/drift.dart';
import 'package:go_habit/core/database/tables/habit_categories.dart';

@DataClassName('Habit')
class Habits extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  /// Local modification time. Not used for conflict resolution: the server orders writes.
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  TextColumn get categoryId => text().references(HabitCategories, #id)(); // Внешний ключ

  /// The row has local changes that have not been pushed to the server yet.
  BoolColumn get isPendingSync => boolean().withDefault(const Constant(false))();
  IntColumn get steps => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get icon => text().withDefault(const Constant(''))();

  /// Tombstone of a local deletion waiting to be pushed. Synced deletions are removed.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// `daily`, `weekly_target` or `weekdays` (see HabitSchedule).
  TextColumn get scheduleType => text().withDefault(const Constant('daily'))();

  /// Completions per week (1–7) for `weekly_target`.
  IntColumn get weeklyTarget => integer().nullable()();

  /// Bit (weekday - 1) per selected day for `weekdays`.
  IntColumn get scheduleDays => integer().nullable()();

  /// `YYYY-MM-DD`: completions before this day do not count for the streak.
  TextColumn get streakResetOn => text().nullable()();

  /// Incremented on every local write, so a push only clears [isPendingSync] if the
  /// row was not modified again while the request was in flight.
  IntColumn get localVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
