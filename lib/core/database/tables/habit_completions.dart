import 'package:drift/drift.dart';
import 'package:go_habit/core/database/tables/habits.dart';

/// One row per habit per calendar day. See `supabase/migrations` for the server side.
@DataClassName('HabitCompletion')
class HabitCompletions extends Table {
  /// Deterministic: derived from habit id and day, identical on every device.
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();

  /// Local calendar day, `YYYY-MM-DD`.
  TextColumn get completedOn => text()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  /// Set when the day is un-marked; the tombstone is kept until it has been pushed.
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isPendingSync => boolean().withDefault(const Constant(false))();
  IntColumn get localVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, completedOn},
      ];
}
