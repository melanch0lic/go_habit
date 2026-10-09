import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';

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
            .having((s) => s.streakOf('h1'), 'streak', 2),
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
