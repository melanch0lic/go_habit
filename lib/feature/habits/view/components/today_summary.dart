import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/feature/habits/domain/today_progress.dart';

/// Today's date and progress: how many habits due today are done, with a ring, and
/// how many weekly goals are reached.
class TodaySummary extends StatelessWidget {
  final TodayProgress progress;
  final DateTime today;

  /// False while completions are still loading: the numbers are not shown yet.
  final bool ready;

  const TodaySummary({required this.progress, required this.today, required this.ready, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final green = context.theme.commonColors.green100;
    final date = MaterialLocalizations.of(context).formatFullDate(today);
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 400);

    final String headline;
    if (!ready) {
      headline = l10n.habits_today_loading;
    } else if (progress.total == 0) {
      headline = l10n.habits_today_nothing;
    } else if (progress.allDone) {
      headline = l10n.habits_today_all_done;
    } else {
      headline = l10n.habits_today_progress(progress.completed, progress.total);
    }
    // Weekly-target habits are not today's obligations; they get their own line.
    final weekGoals = ready && progress.weekly.isNotEmpty
        ? l10n.habits_week_goals(progress.weeklyReached, progress.weekly.length)
        : null;

    return Semantics(
      container: true,
      liveRegion: true,
      label: [date, headline, if (weekGoals != null) weekGoals].join('. '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_capitalize(date), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.25),
                  ),
                  if (weekGoals != null) ...[
                    const SizedBox(height: 2),
                    Text(weekGoals, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox.square(
              dimension: 56,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: ready ? progress.fraction : 0),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        color: green,
                        backgroundColor: green.withValues(alpha: 0.15),
                      ),
                    ),
                    if (progress.allDone)
                      Icon(Icons.check, color: green)
                    else
                      Text(
                        ready && progress.total > 0 ? '${progress.completed}/${progress.total}' : '–',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
