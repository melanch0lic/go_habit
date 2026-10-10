import 'dart:async';

import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/categories/domain/repositories/habit_category_repository.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/domain/repositories/habit_repository.dart';

final today = CalendarDay(2026, 10, 9);

Habit habit(
  String id, {
  String? title,
  bool active = true,
  String category = 'health',
  String icon = '💧',
  HabitSchedule schedule = HabitSchedule.daily,
  CalendarDay? streakResetOn,
}) =>
    Habit(
      id: id,
      title: title ?? 'Habit $id',
      categoryId: category,
      icon: icon,
      isActive: active,
      createdAt: DateTime(2026),
      schedule: schedule,
      streakResetOn: streakResetOn,
    );

/// In-memory habits with the repository's semantics: writes update the stream.
class FakeHabitRepository implements HabitRepository {
  final _habits = <Habit>[];
  final _changes = StreamController<List<Habit>>.broadcast();
  final log = <String>[];

  /// Thrown by the next writes of the named operations.
  final failures = <String>{};
  bool failLoad = false;

  FakeHabitRepository([List<Habit> habits = const []]) {
    _habits.addAll(habits);
  }

  List<Habit> get habits => List.unmodifiable(_habits);

  void _check(String operation) {
    log.add(operation);
    if (failures.contains(operation)) throw StateError('$operation failed');
  }

  void _publish() => _changes.add(List.of(_habits));

  @override
  Future<List<Habit>> getHabits() async {
    if (failLoad) throw StateError('database unavailable');
    return List.of(_habits);
  }

  @override
  Stream<List<Habit>> watchHabits() => _changes.stream;

  @override
  Future<void> addHabit(Habit habit) async {
    _check('add');
    _habits.add(habit);
    _publish();
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    _check('update');
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index >= 0) _habits[index] = habit;
    _publish();
  }

  @override
  Future<void> deleteHabit(String id) async {
    _check('delete');
    _habits.removeWhere((h) => h.id == id);
    _publish();
  }

  Future<void> dispose() => _changes.close();
}

/// In-memory completions; a gate lets tests hold a write in flight.
class FakeStatsRepository implements HabitStatsRepository {
  final _completions = <HabitCompletionModel>[];
  final _controller = StreamController<List<HabitCompletionModel>>.broadcast();
  final writes = <String>[];
  bool fail = false;
  Completer<void>? gate;

  FakeStatsRepository([Map<String, List<CalendarDay>> done = const {}]) {
    for (final MapEntry(key: habitId, value: days) in done.entries) {
      for (final day in days) {
        _completions.add(HabitCompletionModel(id: '$habitId/$day', habitId: habitId, completedOn: day));
      }
    }
  }

  List<HabitCompletionModel> get completions => List.unmodifiable(_completions);

  @override
  Stream<List<HabitCompletionModel>> watchCompletions() async* {
    yield List.of(_completions);
    yield* _controller.stream;
  }

  @override
  Future<void> setCompleted({required String habitId, required CalendarDay day, required bool completed}) async {
    writes.add('$habitId:$completed');
    await gate?.future;
    if (fail) throw StateError('write failed');
    _completions.removeWhere((c) => c.habitId == habitId && c.completedOn == day);
    if (completed) _completions.add(HabitCompletionModel(id: '$habitId/$day', habitId: habitId, completedOn: day));
    _controller.add(List.of(_completions));
  }

  Future<void> dispose() => _controller.close();
}

class FakeCategoryRepository implements HabitCategoryRepository {
  @override
  Future<List<HabitCategory>> getHabitCategories() async => [
        HabitCategory(id: 'health', name: 'Здоровье', color: '#FF6B6B'),
        HabitCategory(id: 'education', name: 'Обучение', color: '#FB8C00'),
        HabitCategory(id: 'sport', name: 'Спорт', color: '#4ECDC4'),
      ];
}
