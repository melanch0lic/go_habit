import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/ui_kit/app_choice_chip.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';

/// Schedule type, its parameter and a summary. Shared by the habit form and the form
/// for a habit created from a community template.
class HabitScheduleSection extends StatelessWidget {
  final ScheduleType type;
  final int weeklyTarget;
  final Set<int> weekdays;
  final bool showWeekdaysError;
  final String? summary;
  final ValueChanged<ScheduleType> onTypeChanged;
  final ValueChanged<int> onTargetChanged;
  final ValueChanged<int> onWeekdayToggled;

  const HabitScheduleSection({
    required this.type,
    required this.weeklyTarget,
    required this.weekdays,
    required this.showWeekdaysError,
    required this.summary,
    required this.onTypeChanged,
    required this.onTargetChanged,
    required this.onWeekdayToggled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final error = theme.colorScheme.error;

    Widget typeChip(ScheduleType value, String label) =>
        AppChoiceChip(label: label, selected: type == value, onSelected: () => onTypeChanged(value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.habits_schedule_label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            typeChip(ScheduleType.daily, l10n.habits_schedule_option_daily),
            typeChip(ScheduleType.weeklyTarget, l10n.habits_schedule_option_weekly),
            typeChip(ScheduleType.weekdays, l10n.habits_schedule_option_weekdays),
          ],
        ),
        if (type == ScheduleType.weeklyTarget) ...[
          const SizedBox(height: 12),
          Text(l10n.habits_weekly_target_label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var count = 1; count <= 7; count++)
                _RoundToggle(
                  label: '$count',
                  semanticsLabel: l10n.habits_schedule_times_per_week(count),
                  selected: weeklyTarget == count,
                  onTap: () => onTargetChanged(count),
                ),
            ],
          ),
        ],
        if (type == ScheduleType.weekdays) ...[
          const SizedBox(height: 12),
          Text(l10n.habits_weekdays_label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                _RoundToggle(
                  label: l10n.weekdayShort(day),
                  selected: weekdays.contains(day),
                  onTap: () => onWeekdayToggled(day),
                ),
            ],
          ),
          if (showWeekdaysError)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(l10n.habits_weekdays_required, style: theme.textTheme.bodySmall?.copyWith(color: error)),
              ),
            ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_repeat, size: 16, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Expanded(child: Text(summary!, style: theme.textTheme.bodySmall)),
            ],
          ),
        ],
      ],
    );
  }
}

/// A round selectable chip for a number or a weekday.
class _RoundToggle extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  const _RoundToggle({required this.label, required this.selected, required this.onTap, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    final green = context.theme.commonColors.green100;
    final theme = context.themeOf;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? green : Colors.transparent,
            border: Border.all(color: selected ? green : theme.dividerColor),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
