import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/habit_card_types.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/widget/habit_completion_button.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/habit_actions.dart';
import 'package:go_habit/feature/habits/view/components/modal_bottom_sheet.dart' show hexToColor;
import 'package:go_habit/feature/habits/view/habit_texts.dart';

/// A habit on the home screen, in the same style as the habits list: icon, name,
/// category and streak, and the round completion control. The chosen display mode
/// (settings) adds this week's progress as a bar, as a ring around the icon, or nothing.
class HabitHomeCard extends StatelessWidget {
  final Habit habit;
  final HabitCategory category;
  final HabitCardDisplayMode displayMode;

  const HabitHomeCard({
    required this.habit,
    required this.category,
    this.displayMode = HabitCardDisplayMode.linear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final color = hexToColor(category.color);
    final green = context.theme.commonColors.green100;
    final stats = context.watch<HabitStatsBloc>().state;
    final loaded = stats is HabitStatsLoaded ? stats : null;
    final completed = loaded?.isCompletedToday(habit.id) ?? false;
    final streak = loaded == null ? null : l10n.streakText(loaded.streakOf(habit));
    final schedule = habit.schedule;
    final week = loaded?.weekProgressOf(habit);
    final description = habit.description?.trim();
    final meta = [
      category.name,
      if (schedule.type != ScheduleType.daily) l10n.scheduleShort(schedule),
      if (streak != null) streak,
    ].join(' · ');
    final weekText = week == null || week.goal == 0
        ? null
        : l10n.weekProgressText(schedule, week) ?? l10n.community_week_progress(week.done, week.goal);
    final fraction = week == null || week.goal == 0 ? null : week.done / week.goal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Semantics(
        container: true,
        label: [
          habit.title,
          meta,
          if (completed) l10n.habits_done_today else l10n.habits_not_done_today,
          if (displayMode != HabitCardDisplayMode.none && weekText != null) weekText,
        ].join(', '),
        child: Material(
          color: completed ? Color.alphaBlend(green.withValues(alpha: 0.08), theme.cardColor) : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => editHabit(context, habit),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: _Icon(
                      emoji: habit.icon ?? '🎯',
                      color: color,
                      // The ring shows this week's progress in the circular mode.
                      ring: displayMode == HabitCardDisplayMode.circular && fraction != null ? fraction * 100 : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                          ),
                          if (description != null && description.isNotEmpty)
                            Text(description,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // The category color, adjusted until it reads as small text on the card.
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color.readableOn(theme.cardColor),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (displayMode == HabitCardDisplayMode.linear && fraction != null) ...[
                            const SizedBox(height: 8),
                            _WeekBar(fraction: fraction, color: color),
                            if (weekText != null) ...[
                              const SizedBox(height: 4),
                              Text(weekText, style: theme.textTheme.bodySmall),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  HabitCompletionButton(
                    habitId: habit.id,
                    round: true,
                    // Non-text UI needs 3:1 against the card.
                    color: color.readableOn(theme.cardColor, ratio: 3),
                    completedColor: green,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  final String emoji;
  final Color color;

  /// 0–100 to draw a progress ring around the icon.
  final double? ring;

  const _Icon({required this.emoji, required this.color, this.ring});

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
    final ring = this.ring;
    if (ring == null) return icon;
    return SizedBox.square(
      dimension: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: _Animated(
              value: ring / 100,
              builder: (value) => CircularProgressIndicator(
                value: value,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          icon,
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final double fraction;
  final Color color;

  const _WeekBar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _Animated(
          value: fraction,
          builder: (value) => LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      );
}

/// Animates progress changes; instant with reduced motion.
class _Animated extends StatelessWidget {
  final double value;
  final Widget Function(double value) builder;

  const _Animated({required this.value, required this.builder});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => builder(value),
      );
}
