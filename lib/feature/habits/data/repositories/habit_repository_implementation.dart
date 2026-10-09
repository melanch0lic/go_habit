import 'package:go_habit/core/sync/sync_service.dart';
import 'package:go_habit/feature/habits/data/data_sources/local/local_habit_data_source.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/repositories/habit_repository.dart';

class HabitsRepositoryImplementation implements HabitRepository {
  final LocalHabitDataSource _localDataSource;
  final SyncScheduler _syncScheduler;

  HabitsRepositoryImplementation(this._localDataSource, this._syncScheduler);

  @override
  Future<List<Habit>> getHabits() => _localDataSource.getHabits();

  @override
  Stream<List<Habit>> watchHabits() => _localDataSource.habitsStream();

  @override
  Future<void> addHabit(Habit habit) async {
    await _localDataSource.saveHabit(habit);
    _syncScheduler.requestSync();
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    await _localDataSource.updateHabit(habit);
    _syncScheduler.requestSync();
  }

  @override
  Future<void> deleteHabit(String id) async {
    await _localDataSource.deleteHabit(id);
    _syncScheduler.requestSync();
  }
}
