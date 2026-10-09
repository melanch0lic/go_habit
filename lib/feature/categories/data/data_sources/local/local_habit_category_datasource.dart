import 'package:drift/drift.dart';
import 'package:go_habit/core/database/dao/habit_category_dao.dart';
import 'package:go_habit/core/database/drift_database.dart' as drift;
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';

abstract interface class LocalHabitCategoryDatasource {
  Future<List<HabitCategory>> getHabitCategories();

  /// Replaces the cache; list order is preserved.
  Future<void> saveAllCategories(List<HabitCategory> categories);
}

class DriftHabitCategoryDataSource implements LocalHabitCategoryDatasource {
  final HabitCategoryDao _habitCategoryDao;

  DriftHabitCategoryDataSource(this._habitCategoryDao);

  @override
  Future<List<HabitCategory>> getHabitCategories() async {
    final categories = await _habitCategoryDao.getAllCategories();
    return categories.map(HabitCategory.fromDriftModel).toList();
  }

  @override
  Future<void> saveAllCategories(List<HabitCategory> categories) => _habitCategoryDao.replaceAll([
        for (final (index, category) in categories.indexed)
          drift.HabitCategoriesCompanion.insert(
            id: category.id,
            name: category.name,
            color: category.color,
            sortOrder: Value(index),
          ),
      ]);
}
