import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_time_picker.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/habit_schedule_section.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';
import 'package:go_habit/feature/notifications/bloc/notification_settings_cubit.dart';

/// The habit's reminder on this device, as one card: the switch with a summary of
/// the time and days, and — when on — the time row and the day selector. The days are
/// independent of the schedule; a weekly target has no fixed days, so the user picks
/// them.
class HabitReminderSection extends StatelessWidget {
  final bool enabled;
  final TimeOfDay time;
  final Set<int> weekdays;
  final bool showDaysError;
  final ScheduleType scheduleType;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final ValueChanged<int> onDayToggled;

  const HabitReminderSection({
    required this.enabled,
    required this.time,
    required this.weekdays,
    required this.showDaysError,
    required this.scheduleType,
    required this.onEnabledChanged,
    required this.onTimeChanged,
    required this.onDayToggled,
    super.key,
  });

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showAppTimePicker(context, initial: time, title: context.l10n.habits_reminder_time);
    if (picked != null) onTimeChanged(picked);
  }

  String _summary(BuildContext context) {
    final l10n = context.l10n;
    if (!enabled) return l10n.habits_reminder_off;
    final days = weekdays.length == 7
        ? l10n.habits_reminder_every_day
        : (weekdays.toList()..sort()).map(l10n.weekdayShort).join(', ');
    return days.isEmpty ? time.format(context) : '${time.format(context)} · $days';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Absent where notifications are not set up (e.g. widget tests of the form).
    NotificationSettingsState? settings;
    try {
      settings = context.watch<NotificationSettingsCubit>().state;
    } on ProviderNotFoundException {
      settings = null;
    }
    final inactive = enabled && settings != null && settings.loaded && !settings.active;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: enabled,
            secondary: Icon(enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
            title: Text(l10n.habits_reminder_toggle),
            subtitle: Text(_summary(context)),
            onChanged: (value) {
              onEnabledChanged(value);
              if (!value) return;
              try {
                // Asked once, when the user first wants a reminder.
                context.read<NotificationSettingsCubit>().ensurePermission();
              } on ProviderNotFoundException {
                // No notifications in this context.
              }
            },
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !enabled
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(l10n.habits_reminder_time),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time.format(context),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                          ],
                        ),
                        onTap: () => _pickTime(context),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l10n.habits_reminder_days, style: theme.textTheme.bodySmall),
                            const SizedBox(height: AppSpacing.xs),
                            WeekdayToggles(selected: weekdays, onToggled: onDayToggled),
                            if (showDaysError)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  l10n.habits_reminder_days_required,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              scheduleType == ScheduleType.weeklyTarget
                                  ? l10n.habits_reminder_weekly_hint
                                  : l10n.habits_reminder_independent_hint,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (inactive) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.notifications_off_outlined, size: 18, color: scheme.error),
                                  const SizedBox(width: AppSpacing.sm),
                                  // A hint only: leaving the form here would drop unsaved changes.
                                  Expanded(
                                      child: Text(l10n.habits_reminder_off_hint, style: theme.textTheme.bodySmall)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
