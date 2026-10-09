import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';

void main() {
  test('uses the local calendar day, not a 24-hour window', () {
    final lateEvening = CalendarDay.fromDateTime(DateTime(2026, 10, 9, 23, 50));
    final nextMorning = CalendarDay.fromDateTime(DateTime(2026, 10, 10, 0, 5));

    expect(lateEvening, CalendarDay(2026, 10, 9));
    expect(nextMorning.differenceInDays(lateEvening), 1);
  });

  test('converts UTC timestamps to local time first', () {
    final utc = DateTime.utc(2026, 10, 9, 12);
    expect(CalendarDay.fromDateTime(utc), CalendarDay.fromDateTime(utc.toLocal()));
  });

  test('round-trips through the Postgres date format', () {
    expect(CalendarDay(2026, 3, 7).toIsoString(), '2026-03-07');
    expect(CalendarDay.parse('2026-03-07'), CalendarDay(2026, 3, 7));
    expect(() => CalendarDay.parse('2026-3-7'), throwsFormatException);
  });

  test('day arithmetic crosses month, year and DST boundaries', () {
    expect(CalendarDay(2026, 12, 31).addDays(1), CalendarDay(2027, 1, 1));
    expect(CalendarDay(2024, 3, 1).addDays(-1), CalendarDay(2024, 2, 29));
    // 2026-03-29 is a 23-hour day in many European time zones.
    expect(CalendarDay(2026, 3, 30).differenceInDays(CalendarDay(2026, 3, 29)), 1);
  });

  test('is ordered and usable as a map key', () {
    final days = [CalendarDay(2026, 1, 2), CalendarDay(2025, 12, 31), CalendarDay(2026, 1, 1)]..sort();
    expect(days.first, CalendarDay(2025, 12, 31));
    expect({CalendarDay(2026, 1, 1), CalendarDay(2026, 1, 1)}, hasLength(1));
  });
}
