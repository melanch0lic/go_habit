import 'package:drift/drift.dart';
import 'package:go_habit/core/database/drift_database.dart';
import 'package:go_habit/core/database/tables/notifications.dart';

part 'notifications_dao.g.dart';

@DriftAccessor(tables: [HabitReminders, NotificationHistory])
class NotificationsDao extends DatabaseAccessor<AppDatabase> with _$NotificationsDaoMixin {
  NotificationsDao(super.db);

  // ----- Reminders -----

  Stream<List<HabitReminderEntry>> watchReminders() => select(habitReminders).watch();

  Future<List<HabitReminderEntry>> getReminders() => select(habitReminders).get();

  Future<void> saveReminder(HabitRemindersCompanion reminder) => into(habitReminders).insertOnConflictUpdate(reminder);

  Future<void> deleteReminder(String habitId) => (delete(habitReminders)..where((t) => t.habitId.equals(habitId))).go();

  /// Removes reminders of habits that no longer exist on this device.
  Future<void> deleteRemindersExcept(Set<String> habitIds) =>
      (delete(habitReminders)..where((t) => t.habitId.isNotIn(habitIds))).go();

  // ----- History -----

  Stream<List<NotificationHistoryEntry>> watchHistory() =>
      (select(notificationHistory)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  /// Inserts the event once; a repeated event keeps the existing record (and its
  /// read state). Returns whether a record was added.
  Future<bool> addOnce(NotificationHistoryCompanion entry) async =>
      // Whether a row came back, not the rowid: an ignored insert still reports the last rowid.
      await into(notificationHistory).insertReturningOrNull(entry, mode: InsertMode.insertOrIgnore) != null;

  Future<void> markRead(String id, DateTime at) =>
      (update(notificationHistory)..where((t) => t.id.equals(id) & t.readAt.isNull()))
          .write(NotificationHistoryCompanion(readAt: Value(at)));

  Future<void> markAllRead(DateTime at) => (update(notificationHistory)..where((t) => t.readAt.isNull()))
      .write(NotificationHistoryCompanion(readAt: Value(at)));

  Future<void> deleteEntry(String id) => (delete(notificationHistory)..where((t) => t.id.equals(id))).go();

  Future<void> clearHistory() => delete(notificationHistory).go();
}
