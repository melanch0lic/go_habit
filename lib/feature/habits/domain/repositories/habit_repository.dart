import 'package:go_habit/feature/habits/data/models/habit.dart';

/// Local-first: reads and writes go to the device database; synchronization with
/// the server happens in the background.
abstract interface class HabitRepository {
  Future<List<Habit>> getHabits();
  Future<void> addHabit(Habit habit);
  Future<void> updateHabit(Habit habit);
  Future<void> deleteHabit(String id);
  Stream<List<Habit>> watchHabits();
}
