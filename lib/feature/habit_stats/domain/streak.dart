import 'package:go_habit/core/utils/calendar_day.dart';

/// Number of consecutive completed days ending today, or ending yesterday if today
/// is not completed yet (the streak is not broken until the day is over).
///
/// Streaks are derived from completion records and never stored.
int currentStreak(Iterable<CalendarDay> completedDays, CalendarDay today) {
  final days = completedDays.toSet();
  var cursor = days.contains(today) ? today : today.addDays(-1);
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.addDays(-1);
  }
  return streak;
}
