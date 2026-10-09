import 'package:go_habit/core/database/dao/habit_completion_dao.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';

abstract interface class LocalHabitStatsDataSource {
  Stream<List<HabitCompletionModel>> watchCompletions();
  Future<void> setCompleted(String habitId, CalendarDay day, {required bool completed});
}

class LocalStatsDataSourceImpl implements LocalHabitStatsDataSource {
  final HabitCompletionDao _completionDao;

  LocalStatsDataSourceImpl(this._completionDao);

  @override
  Stream<List<HabitCompletionModel>> watchCompletions() =>
      _completionDao.watchCompletions().map((rows) => rows.map(HabitCompletionModel.fromDriftModel).toList());

  @override
  Future<void> setCompleted(String habitId, CalendarDay day, {required bool completed}) =>
      _completionDao.setCompleted(habitId, day, completed: completed);
}
