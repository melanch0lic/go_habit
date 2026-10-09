import 'package:go_habit/core/app_connect/src/app_connect.dart';
import 'package:go_habit/feature/categories/data/data_sources/local/local_habit_category_datasource.dart';
import 'package:go_habit/feature/categories/data/data_sources/remote/remote_habit_category_datasource.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/categories/domain/repositories/habit_category_repository.dart';
import 'package:l/l.dart';

class HabitCategoryRepositoryImplementation implements HabitCategoryRepository {
  final LocalHabitCategoryDatasource _localHabitCategoryDatasource;
  final RemoteHabitCategoryDatasource _remoteHabitCategoryDatasource;
  final IAppConnect _appConnect;

  HabitCategoryRepositoryImplementation(
      this._localHabitCategoryDatasource, this._remoteHabitCategoryDatasource, this._appConnect);

  /// Refreshes the cache from the server when possible and always answers from the cache.
  /// Throws only if there is nothing cached and the server could not be reached.
  @override
  Future<List<HabitCategory>> getHabitCategories() async {
    if (await _appConnect.hasConnect()) {
      try {
        final remoteCategories = await _remoteHabitCategoryDatasource.getHabitCategories();
        if (remoteCategories.isNotEmpty) {
          await _localHabitCategoryDatasource.saveAllCategories(remoteCategories);
        }
      } on Object catch (error, stackTrace) {
        l.w('Could not refresh categories, using cache: $error', stackTrace);
      }
    }
    final cached = await _localHabitCategoryDatasource.getHabitCategories();
    if (cached.isEmpty) throw StateError('No categories available');
    return cached;
  }
}
