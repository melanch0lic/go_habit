import 'package:drift/drift.dart';
import 'package:go_habit/core/database/dao/habits_dao.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart' as entity;

abstract interface class LocalHabitDataSource {
  Future<List<entity.Habit>> getHabits();
  Future<entity.Habit?> getHabitById(String id);
  Stream<List<entity.Habit>> habitsStream();

  /// Writes below are queued for synchronization.
  Future<void> saveHabit(entity.Habit habit);
  Future<void> updateHabit(entity.Habit habit);
  Future<void> deleteHabit(String id);
}

class DriftHabitDataSource implements LocalHabitDataSource {
  final HabitsDao _habitsDao;

  DriftHabitDataSource(this._habitsDao);

  @override
  Future<List<entity.Habit>> getHabits() async =>
      (await _habitsDao.getAllHabits()).map(entity.Habit.fromDriftModel).toList();

  @override
  Future<entity.Habit?> getHabitById(String id) async {
    final habit = await _habitsDao.getHabitById(id);
    return habit == null ? null : entity.Habit.fromDriftModel(habit);
  }

  @override
  Stream<List<entity.Habit>> habitsStream() =>
      _habitsDao.watchHabits().map((rows) => rows.map(entity.Habit.fromDriftModel).toList());

  @override
  Future<void> saveHabit(entity.Habit habit) => _habitsDao.insertLocal(
        HabitsCompanion.insert(
          id: habit.id,
          title: habit.title,
          description: Value(habit.description),
          categoryId: habit.categoryId,
          isActive: Value(habit.isActive),
          steps: Value(habit.steps),
          icon: Value(habit.icon ?? '🎯'),
          createdAt: Value(habit.createdAt),
        ),
      );

  @override
  Future<void> updateHabit(entity.Habit habit) async {
    final updated = await _habitsDao.updateLocal(
      habit.id,
      title: habit.title,
      description: habit.description,
      categoryId: habit.categoryId,
      steps: habit.steps,
      isActive: habit.isActive,
      icon: habit.icon,
    );
    if (updated == 0) throw StateError('Habit ${habit.id} does not exist');
  }

  @override
  Future<void> deleteHabit(String id) => _habitsDao.markDeleted(id);
}
