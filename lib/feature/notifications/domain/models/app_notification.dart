import 'package:flutter/foundation.dart';

/// What an in-app notification is about. New kinds (e.g. server-driven community
/// or friend activity) get a new value; unknown stored values read as [system].
enum NotificationCategory {
  habitReminder('habit_reminder'),
  dailyProgress('daily_progress'),
  streakRisk('streak_risk'),
  system('system');

  /// Stored value.
  final String wire;

  const NotificationCategory(this.wire);

  static NotificationCategory parse(String? value) =>
      values.where((category) => category.wire == value).firstOrNull ?? system;
}

/// A record of the in-app notification history (the Notifications Center). It is
/// application data, separate from scheduled operating-system reminders: deleting a
/// record never cancels a reminder, and cancelling a reminder never deletes history.
@immutable
class AppNotification {
  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final String? habitId;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.habitId,
    this.readAt,
  });

  bool get isRead => readAt != null;

  @override
  bool operator ==(Object other) =>
      other is AppNotification &&
      other.id == id &&
      other.category == category &&
      other.title == title &&
      other.body == body &&
      other.habitId == habitId &&
      other.createdAt == createdAt &&
      other.readAt == readAt;

  @override
  int get hashCode => Object.hash(id, category, title, body, habitId, createdAt, readAt);
}
