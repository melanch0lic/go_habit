import 'package:drift/drift.dart';

/// Per-device reminder settings of a habit. Local only: reminders are a property of
/// the device, so they are not synchronized and work offline.
@DataClassName('HabitReminderEntry')
class HabitReminders extends Table {
  TextColumn get habitId => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// Minutes after local midnight, 0–1439.
  IntColumn get minuteOfDay => integer()();

  /// Bit (ISO weekday - 1) per reminder day, 1–127 (Monday = 1, Sunday = 64).
  IntColumn get daysMask => integer()();

  @override
  Set<Column> get primaryKey => {habitId};
}

/// The in-app notification history: events the app saw happen (a notification on
/// screen or tapped), not scheduled future reminders.
@DataClassName('NotificationHistoryEntry')
class NotificationHistory extends Table {
  /// Stable event id, so processing the same event twice keeps one record.
  TextColumn get id => text()();

  /// `NotificationCategory.wire`; unknown values (from a newer app) read as system.
  TextColumn get category => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();

  /// The habit the notification is about, if any.
  TextColumn get habitId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
