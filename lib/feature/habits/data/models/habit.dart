import 'package:flutter/foundation.dart';
import 'package:go_habit/core/database/drift_database.dart' as drift;
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
    );
  }

  factory Habit.fromDriftModel(drift.Habit habit) {
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
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, title, description, categoryId, createdAt, updatedAt, isActive, steps, icon);

  @override
  String toString() => 'Habit($id, $title)';
}
