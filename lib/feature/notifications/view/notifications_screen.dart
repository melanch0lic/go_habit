import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/notifications/domain/models/notification.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  List<NotificationModel> _getMockNotifications() {
    return [
      NotificationModel(
        id: '1',
        title: 'Привычка выполнена',
        message: 'Вы успешно выполнили привычку "Медитация"',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        type: NotificationType.habit,
        habitId: 'habit1',
        icon: Icons.check_circle,
      ),
      NotificationModel(
        id: '2',
        title: 'Новое достижение',
        message: 'Поздравляем! Вы достигли 7-дневной серии в привычке "Чтение"',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: NotificationType.achievement,
        habitId: 'habit2',
        icon: Icons.emoji_events,
      ),
      NotificationModel(
        id: '3',
        title: 'Напоминание',
        message: 'Не забудьте выполнить привычку "Спорт" сегодня',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        type: NotificationType.reminder,
        habitId: 'habit3',
        icon: Icons.notifications,
      ),
      NotificationModel(
        id: '4',
        title: 'Обновление приложения',
        message: 'Доступно новое обновление Go Habit',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: NotificationType.system,
        icon: Icons.system_update,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _getMockNotifications();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notifications),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              // TODO: Mark all as read
            },
          ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет новых уведомлений',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    // TODO: Delete notification
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: notification.getColor().withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notification.icon,
                          color: notification.getColor(),
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.message),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(notification.timestamp),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      trailing: notification.isRead
                          ? null
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: notification.getColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                      onTap: () {
                        // TODO: Handle notification tap
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
