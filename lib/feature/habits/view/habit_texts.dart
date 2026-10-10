import 'package:go_habit/feature/habit_stats/domain/streak.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/l10n/app_localizations.dart';

/// Texts for schedules and streaks, shared by every screen that shows habits, so a
/// streak is never a bare number.
extension HabitTexts on AppLocalizations {
  /// "Пн" … "Вс".
  String weekdayShort(int weekday) => switch (weekday) {
        DateTime.monday => habits_weekday_1,
        DateTime.tuesday => habits_weekday_2,
        DateTime.wednesday => habits_weekday_3,
        DateTime.thursday => habits_weekday_4,
        DateTime.friday => habits_weekday_5,
        DateTime.saturday => habits_weekday_6,
        _ => habits_weekday_7,
      };

  /// Short form for cards: "Каждый день", "3 раза в неделю", "Пн, Ср, Пт".
  String scheduleShort(HabitSchedule schedule) => switch (schedule.type) {
        ScheduleType.daily => habits_schedule_daily,
        ScheduleType.weeklyTarget => habits_schedule_times_per_week(schedule.weeklyTarget!),
        ScheduleType.weekdays => schedule.sortedWeekdays.map(weekdayShort).join(', '),
      };

  /// Sentence for the form summary.
  String scheduleSummary(HabitSchedule schedule) => switch (schedule.type) {
        ScheduleType.weeklyTarget => habits_schedule_weekly_summary(schedule.weeklyTarget!),
        _ => scheduleShort(schedule),
      };

  /// "5 дней подряд", "3 недели подряд", "4 раза подряд"; null without a streak.
  String? streakText(HabitStreak streak) {
    if (streak.count == 0) return null;
    return switch (streak.unit) {
      StreakUnit.days => habits_streak(streak.count),
      StreakUnit.weeks => habits_streak_weeks(streak.count),
      StreakUnit.occurrences => habits_streak_occurrences(streak.count),
    };
  }

  /// This week's progress where it matters: weekly targets and weekdays. Daily habits
  /// show today's mark instead.
  String? weekProgressText(HabitSchedule schedule, WeekProgress progress) => switch (schedule.type) {
        ScheduleType.daily => null,
        ScheduleType.weeklyTarget => habits_week_target_progress(progress.done, progress.goal),
        ScheduleType.weekdays => habits_weekdays_progress(progress.done, progress.goal),
      };
}
