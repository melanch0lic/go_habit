import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';
import 'package:go_habit/feature/habit_stats/domain/streak.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

Habit _habit(String id, {HabitSchedule schedule = HabitSchedule.daily, CalendarDay? streakResetOn}) => Habit(
      id: id,
      title: id,
      categoryId: 'health',
      createdAt: DateTime(2026),
      schedule: schedule,
      streakResetOn: streakResetOn,
    );

class _FakeStatsRepository implements HabitStatsRepository {
  final completions = StreamController<List<HabitCompletionModel>>.broadcast();
  final calls = <(String, CalendarDay, bool)>[];
  Error? failWith;

  Future<void> dispose() => completions.close();

  @override
  Stream<List<HabitCompletionModel>> watchCompletions() => completions.stream;

  @override
  Future<void> setCompleted({required String habitId, required CalendarDay day, required bool completed}) async {
    if (failWith != null) throw failWith!;
    calls.add((habitId, day, completed));
  }
}

void main() {
  final now = DateTime(2026, 10, 9, 23, 50);
  final today = CalendarDay(2026, 10, 9);
  late _FakeStatsRepository repository;
  late HabitStatsBloc bloc;

  HabitCompletionModel completion(String habitId, CalendarDay day) =>
      HabitCompletionModel(id: '$habitId/$day', habitId: habitId, completedOn: day);

  setUp(() {
    repository = _FakeStatsRepository();
    bloc = HabitStatsBloc(repository, now: () => now);
  });

  tearDown(() async {
    await bloc.close();
    await repository.dispose();
  });

  test('emits loading, then completions with today derived from the injected clock', () async {
    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<HabitStatsLoading>(),
        isA<HabitStatsLoaded>()
            .having((s) => s.today, 'today', today)
            .having((s) => s.isCompletedToday('h1'), 'h1 done today', isTrue)
            .having((s) => s.isCompletedToday('h2'), 'h2 done today', isFalse)
            .having((s) => s.streakOf(_habit('h1')), 'streak', const HabitStreak(2, StreakUnit.days)),
      ]),
    );
    bloc.add(HabitsStatsInitialLoad());
    await pumpEventQueue();
    repository.completions.add([completion('h1', today), completion('h1', today.addDays(-1))]);
    await expectation;
  });

  test('toggling marks today when it is not completed, and un-marks it when it is', () async {
    bloc.add(HabitsStatsInitialLoad());
    await pumpEventQueue();
    repository.completions.add([completion('done', today)]);
    await pumpEventQueue();

    bloc
      ..add(HabitCompletionToggled('open'))
      ..add(HabitCompletionToggled('done'));
    await pumpEventQueue();

    expect(repository.calls, [('open', today, true), ('done', today, false)]);
  });

  test("streaks and week progress follow each habit's schedule and reset day", () async {
    bloc.add(HabitsStatsInitialLoad());
    await pumpEventQueue();
    // Today is Friday: Monday, Tuesday, Wednesday of this week and of the last one.
    final monday = today.weekStart;
    repository.completions.add([
      for (final day in [monday, monday.addDays(1), monday.addDays(2)]) ...[
        completion('h1', day),
        completion('h1', day.addDays(-7)),
      ],
    ]);
    await pumpEventQueue();

    final state = bloc.state as HabitStatsLoaded;
    final weekly = _habit('h1', schedule: HabitSchedule.weeklyTarget(3));
    expect(state.streakOf(weekly), const HabitStreak(2, StreakUnit.weeks));
    expect(state.weekProgressOf(weekly), const WeekProgress(3, 3));
    expect(
      state.streakOf(_habit('h1', schedule: HabitSchedule.weeklyTarget(3), streakResetOn: monday)),
      const HabitStreak(1, StreakUnit.weeks),
      reason: 'last week is before the reset day',
    );
    expect(
      state.streakOf(_habit('h1', schedule: HabitSchedule.weekdays({DateTime.monday, DateTime.wednesday}))),
      const HabitStreak(4, StreakUnit.occurrences),
    );
  });

  test('a completion from yesterday does not count as today', () async {
    bloc.add(HabitsStatsInitialLoad());
    await pumpEventQueue();
    repository.completions.add([completion('h1', today.addDays(-1))]);
    await pumpEventQueue();

    bloc.add(HabitCompletionToggled('h1'));
    await pumpEventQueue();

    expect(repository.calls.single.$3, isTrue);
  });

  test('a failed write is reported without breaking the state', () async {
    bloc.add(HabitsStatsInitialLoad());
    await pumpEventQueue();
    repository
      ..completions.add(const [])
      ..failWith = StateError('disk full');
    await pumpEventQueue();
    bloc.add(HabitCompletionToggled('h1'));
    await pumpEventQueue();

    expect(bloc.state, isA<HabitStatsLoaded>());
    expect(repository.calls, isEmpty);
  });
}
