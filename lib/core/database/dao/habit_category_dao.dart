import 'package:drift/drift.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/database/tables/habit_categories.dart';

part 'habit_category_dao.g.dart';

@DriftAccessor(tables: [HabitCategories])
class HabitCategoryDao extends DatabaseAccessor<AppDatabase> with _$HabitCategoryDaoMixin {
  HabitCategoryDao(super.db);

  Future<List<HabitCategory>> getAllCategories() =>
      (select(habitCategories)..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).get();

  /// Replaces the cached reference list with the server's.
  Future<void> replaceAll(List<HabitCategoriesCompanion> categories) => transaction(() async {
        await delete(habitCategories).go();
        await batch((batch) => batch.insertAll(habitCategories, categories));
      });
}
