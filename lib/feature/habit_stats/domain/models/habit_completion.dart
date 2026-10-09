import 'package:flutter/foundation.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/utils/calendar_day.dart';

/// A habit was completed on [completedOn] (a calendar day in local time).
@immutable
class HabitCompletionModel {
  final String id;
  final String habitId;
  final CalendarDay completedOn;

  const HabitCompletionModel({
    required this.id,
    required this.habitId,
    required this.completedOn,
  });

  factory HabitCompletionModel.fromDriftModel(HabitCompletion completion) {
    return HabitCompletionModel(
      id: completion.id,
      habitId: completion.habitId,
      completedOn: CalendarDay.parse(completion.completedOn),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HabitCompletionModel && other.id == id && other.habitId == habitId && other.completedOn == completedOn;

  @override
  int get hashCode => Object.hash(id, habitId, completedOn);
}
