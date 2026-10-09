import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/data/data_sources/local/local_habit_stats_datasource.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';

class HabitStatsRepositoryImplementation implements HabitStatsRepository {
  final LocalHabitStatsDataSource _localDataSource;
  final SyncScheduler _syncScheduler;

  HabitStatsRepositoryImplementation(this._localDataSource, this._syncScheduler);

  @override
  Stream<List<HabitCompletionModel>> watchCompletions() => _localDataSource.watchCompletions();

  @override
  Future<void> setCompleted({required String habitId, required CalendarDay day, required bool completed}) async {
    await _localDataSource.setCompleted(habitId, day, completed: completed);
    _syncScheduler.requestSync();
  }
}
