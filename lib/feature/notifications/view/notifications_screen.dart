import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/notifications/bloc/notification_center_bloc.dart';
import 'package:go_habit/feature/notifications/domain/models/app_notification.dart';
import 'package:go_habit/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// The Notifications Center: the app's own notification history (reminders the user
/// saw or opened), newest first and grouped by day. It does not list scheduled
/// reminders, and deleting a record never cancels one.
class NotificationsScreen extends StatelessWidget {
  /// For tests; the app uses the clock.
  final DateTime Function()? now;

  const NotificationsScreen({this.now, super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final bloc = context.read<NotificationCenterBloc>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.notifications_clear_title),
        content: Text(l10n.notifications_clear_message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.notifications_clear_confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(const NotificationHistoryCleared());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<NotificationCenterBloc>().state;
    final hasItems = state.items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          IconButton(
            tooltip: l10n.notifications_mark_all_read,
            icon: const Icon(Icons.done_all),
            onPressed: state.unreadCount > 0
                ? () => context.read<NotificationCenterBloc>().add(const NotificationsAllRead())
                : null,
          ),
          IconButton(
            tooltip: l10n.notifications_settings_title,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(ProfileRoutes.notificationSettings.path),
          ),
          if (hasItems)
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => _confirmClear(context),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                    title: Text(l10n.notifications_clear_all),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: switch (state.status) {
        NotificationCenterStatus.loading => const Center(child: CircularProgressIndicator.adaptive()),
        NotificationCenterStatus.failure => _Message(
            icon: Icons.error_outline,
            title: l10n.notifications_load_failed,
            action: l10n.communities_retry,
            onAction: () => context.read<NotificationCenterBloc>().add(const NotificationCenterStarted()),
          ),
        NotificationCenterStatus.ready when !hasItems => _Message(
            icon: Icons.notifications_none,
            title: l10n.notifications_empty,
            body: l10n.notifications_empty_hint,
            action: l10n.notifications_settings_title,
            onAction: () => context.push(ProfileRoutes.notificationSettings.path),
          ),
        NotificationCenterStatus.ready => _HistoryList(items: state.items, now: (now ?? DateTime.now)()),
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<AppNotification> items;
  final DateTime now;

  const _HistoryList({required this.items, required this.now});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String groupOf(AppNotification item) {
      if (!item.createdAt.isBefore(today)) return l10n.notifications_today;
      if (!item.createdAt.isBefore(yesterday)) return l10n.notifications_yesterday;
      return l10n.notifications_earlier;
    }

    final rows = <Widget>[];
    String? group;
    for (final item in items) {
      final next = groupOf(item);
      if (next != group) {
        group = next;
        rows.add(_GroupHeader(title: next));
      }
      rows.add(_NotificationTile(key: ValueKey(item.id), item: item, now: now));
    }

    return ListView(
      // The bottom inset includes the floating navigation bar.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: rows,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;

  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// One record: category icon, title, message, category and time. Unread records
/// have a dot, a bold title and say "Unread" to screen readers.
class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final DateTime now;

  const _NotificationTile({required this.item, required this.now, super.key});

  void _open(BuildContext context) {
    context.read<NotificationCenterBloc>().add(NotificationRead(item.id));
    final habitId = item.habitId;
    if (item.category == NotificationCategory.system) return;
    if (habitId == null) {
      context.go(CalendarRoutes.calendar.path);
      return;
    }
    final exists = context.read<HabitsBloc>().state.habits.any((habit) => habit.id == habitId);
    if (!exists) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.notifications_habit_missing)));
      return;
    }
    context.go(CalendarRoutes.openHabit(habitId, request: '${item.id}@${DateTime.now().microsecondsSinceEpoch}'));
  }

  void _delete(BuildContext context) => context.read<NotificationCenterBloc>().add(NotificationDeleted(item.id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, category) = categoryStyle(item.category, l10n);
    final unread = !item.isRead;
    final when = relativeTime(item.createdAt, now, context);
    final exact = exactTime(item.createdAt, context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey('dismiss-${item.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(context),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.xl),
          decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(AppRadius.card)),
          child: Icon(Icons.delete_outline, color: scheme.onError),
        ),
        child: Semantics(
          container: true,
          button: true,
          label: [if (unread) l10n.notifications_unread, item.title, item.body, category, exact].join('. '),
          excludeSemantics: true,
          customSemanticsActions: {
            CustomSemanticsAction(label: l10n.notifications_delete): () => _delete(context),
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            color: unread ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.06), scheme.surface) : null,
            child: InkWell(
              onTap: () => _open(context),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                      child: Icon(icon, size: 22, color: scheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (unread)
                                Padding(
                                  padding: const EdgeInsets.only(left: AppSpacing.sm, top: 6),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
                          if (item.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(item.body,
                                maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Tooltip(
                            message: exact,
                            child: Text('$category · $when', style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon and label of a category.
(IconData, String) categoryStyle(NotificationCategory category, AppLocalizations l10n) => switch (category) {
      NotificationCategory.habitReminder => (Icons.alarm, l10n.notifications_category_habit),
      NotificationCategory.dailyProgress => (Icons.checklist, l10n.notifications_category_progress),
      NotificationCategory.streakRisk => (Icons.local_fire_department_outlined, l10n.notifications_category_streak),
      NotificationCategory.system => (Icons.info_outline, l10n.notifications_category_system),
    };

/// "только что", "5 мин назад", "3 ч назад" today; "Вчера, 21:00"; a short date with
/// the time before that.
String relativeTime(DateTime at, DateTime now, BuildContext context) {
  final l10n = context.l10n;
  final material = MaterialLocalizations.of(context);
  final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: true);
  final today = DateTime(now.year, now.month, now.day);
  final difference = now.difference(at);
  if (!at.isBefore(today)) {
    if (difference.inMinutes < 1) return l10n.notifications_just_now;
    if (difference.inMinutes < 60) return l10n.notifications_minutes_ago(difference.inMinutes);
    return l10n.notifications_hours_ago(difference.inHours);
  }
  if (!at.isBefore(today.subtract(const Duration(days: 1)))) return '${l10n.notifications_yesterday}, $time';
  return '${material.formatShortMonthDay(at)}, $time';
}

/// The full date and time, for tooltips and screen readers.
String exactTime(DateTime at, BuildContext context) {
  final material = MaterialLocalizations.of(context);
  return '${material.formatFullDate(at)}, '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: true)}';
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  const _Message({required this.icon, required this.title, this.body, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = this.body;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
