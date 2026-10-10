import 'package:flutter/foundation.dart';
import 'package:go_habit/core/database/drift_database.dart' as drift;
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:uuid/uuid.dart';

/// A habit definition. Completion state lives in `habit_stats` (one record per day).
@immutable
class Habit {
  final String id;
  final String title;
  final String? description;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int steps;
  final String? icon;
  final HabitSchedule schedule;

  /// Completions before this day do not count for the streak. Set when the schedule
  /// type changes; the completion history itself is kept.
  final CalendarDay? streakResetOn;

  Habit({
    String? id,
    required this.title,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.categoryId,
    this.isActive = true,
    this.icon,
    this.steps = 0,
    this.schedule = HabitSchedule.daily,
    this.streakResetOn,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  Habit copyWith({
    String? title,
    String? description,
    String? categoryId,
    bool? isActive,
    int? steps,
    String? icon,
    HabitSchedule? schedule,
    CalendarDay? streakResetOn,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isActive: isActive ?? this.isActive,
      steps: steps ?? this.steps,
      icon: icon ?? this.icon,
      schedule: schedule ?? this.schedule,
      streakResetOn: streakResetOn ?? this.streakResetOn,
    );
  }

  factory Habit.fromDriftModel(drift.Habit habit) {
    final resetOn = habit.streakResetOn;
    return Habit(
      id: habit.id,
      title: habit.title,
      description: habit.description,
      categoryId: habit.categoryId,
      createdAt: habit.createdAt,
      updatedAt: habit.updatedAt,
      isActive: habit.isActive,
      steps: habit.steps,
      icon: habit.icon,
      schedule: HabitSchedule.fromStorage(
        type: habit.scheduleType,
        weeklyTarget: habit.weeklyTarget,
        daysMask: habit.scheduleDays,
      ),
      streakResetOn: resetOn == null ? null : CalendarDay.parse(resetOn),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Habit &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.categoryId == categoryId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.isActive == isActive &&
      other.steps == steps &&
      other.icon == icon &&
      other.schedule == schedule &&
      other.streakResetOn == streakResetOn;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        categoryId,
        createdAt,
        updatedAt,
        isActive,
        steps,
        icon,
        schedule,
        streakResetOn,
      );

  @override
  String toString() => 'Habit($id, $title)';
}
