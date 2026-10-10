import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_section.dart';
import 'package:go_habit/core/ui_kit/app_time_picker.dart';
import 'package:go_habit/feature/notifications/bloc/notification_settings_cubit.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';

/// Notification preferences: the system permission, the app's master switch and the
/// optional daily progress and streak reminders. Habit reminders are set per habit.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<NotificationSettingsCubit>().state;
    final cubit = context.read<NotificationSettingsCubit>();
    final preferences = state.preferences;
    final enabled = preferences.enabled;

    Future<void> pickTime(TimeOfDay initial, Future<void> Function(TimeOfDay) save, String title) async {
      final picked = await showAppTimePicker(context, initial: initial, title: title);
      if (picked != null) await save(picked);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications_settings_title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (state.loaded && state.permission != NotificationPermission.granted) ...[
            _PermissionBanner(permission: state.permission),
            const SizedBox(height: AppSpacing.section),
          ],
          AppSection(
            children: [
              SwitchListTile(
                value: enabled,
                onChanged: cubit.setEnabled,
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(l10n.notifications_master),
                subtitle: Text(l10n.notifications_master_hint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          AppSection(
            title: l10n.notifications_habit_reminders,
            children: [
              ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(l10n.notifications_habit_reminders_hint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          AppSection(
            title: l10n.notifications_extra_reminders,
            children: [
              SwitchListTile(
                value: preferences.dailyProgress,
                onChanged: enabled ? cubit.setDailyProgress : null,
                secondary: const Icon(Icons.checklist),
                title: Text(l10n.notifications_progress_setting),
                subtitle: Text(l10n.notifications_progress_setting_hint),
              ),
              if (preferences.dailyProgress)
                AppSettingsTile(
                  icon: Icons.schedule,
                  title: l10n.notifications_time(preferences.dailyProgressTime.format(context)),
                  onTap: enabled
                      ? () => pickTime(preferences.dailyProgressTime, cubit.setDailyProgressTime,
                          l10n.notifications_progress_setting)
                      : null,
                ),
              SwitchListTile(
                value: preferences.streakRisk,
                onChanged: enabled ? cubit.setStreakRisk : null,
                secondary: const Icon(Icons.local_fire_department_outlined),
                title: Text(l10n.notifications_streak_setting),
                subtitle: Text(l10n.notifications_streak_setting_hint),
              ),
              if (preferences.streakRisk)
                AppSettingsTile(
                  icon: Icons.schedule,
                  title: l10n.notifications_time(preferences.streakRiskTime.format(context)),
                  onTap: enabled
                      ? () => pickTime(
                          preferences.streakRiskTime, cubit.setStreakRiskTime, l10n.notifications_streak_setting)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(l10n.notifications_delivery_hint, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Explains why reminders cannot appear and offers the one action that helps.
class _PermissionBanner extends StatelessWidget {
  final NotificationPermission permission;

  const _PermissionBanner({required this.permission});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<NotificationSettingsCubit>();
    final (text, action, onAction) = switch (permission) {
      NotificationPermission.notRequested => (
          l10n.notifications_permission_request,
          l10n.notifications_allow,
          cubit.ensurePermission,
        ),
      NotificationPermission.denied => (
          l10n.notifications_permission_denied,
          l10n.notifications_open_settings,
          cubit.openSystemSettings,
        ),
      NotificationPermission.unsupported || NotificationPermission.granted => (
          l10n.notifications_permission_unsupported,
          null,
          null,
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.theme.warningContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_off_outlined, color: theme.colorScheme.onSurface),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: onAction, child: Text(action)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
