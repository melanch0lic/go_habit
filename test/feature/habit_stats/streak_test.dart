import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/domain/streak.dart';

void main() {
  final today = CalendarDay(2026, 10, 9);
  List<CalendarDay> daysAgo(List<int> offsets) => [for (final o in offsets) today.addDays(-o)];

  test('no completions means no streak', () => expect(currentStreak([], today), 0));

  test('counts consecutive days ending today', () => expect(currentStreak(daysAgo([0, 1, 2]), today), 3));

  test("today not done yet keeps yesterday's streak alive", () {
    expect(currentStreak(daysAgo([1, 2, 3]), today), 3);
  });

  test('a missed day breaks the streak', () {
    expect(currentStreak(daysAgo([0, 1, 3, 4]), today), 2);
    expect(currentStreak(daysAgo([2, 3]), today), 0);
  });

  test('duplicates and order do not matter', () {
    expect(currentStreak(daysAgo([1, 0, 1, 0]), today), 2);
  });
}
