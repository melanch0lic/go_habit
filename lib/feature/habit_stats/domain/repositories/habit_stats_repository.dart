import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';

abstract interface class HabitStatsRepository {
  /// Completions of all non-deleted habits, from the local database.
  Stream<List<HabitCompletionModel>> watchCompletions();

  /// Marks or un-marks [day] for a habit. Repeating the call is harmless.
  Future<void> setCompleted({required String habitId, required CalendarDay day, required bool completed});
}
