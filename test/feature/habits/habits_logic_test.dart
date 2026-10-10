import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/domain/today_progress.dart';

import 'habits_fakes.dart';

void main() {
  group('TodayProgress', () {
    test('counts only active habits as scheduled for today', () {
      final progress = TodayProgress.of(
        [habit('a'), habit('b'), habit('p', active: false)],
        today: today,
        isCompletedToday: (id) => id == 'a' || id == 'p',
      );
      expect(progress.total, 2);
      expect(progress.completed, 1, reason: 'a completion of a paused habit does not count');
      expect(progress.paused.map((h) => h.id), ['p']);
      expect(progress.fraction, 0.5);
      expect(progress.allDone, isFalse);
    });

    test('all done, nothing scheduled, and no habits at all are different states', () {
      final allDone = TodayProgress.of([habit('a')], today: today, isCompletedToday: (_) => true);
      expect(allDone.allDone, isTrue);

      final allPaused = TodayProgress.of([habit('p', active: false)], today: today, isCompletedToday: (_) => false);
      expect(allPaused.total, 0);
      expect(allPaused.hasHabits, isTrue);
      expect(allPaused.allDone, isFalse, reason: 'nothing scheduled is not "all done"');
      expect(allPaused.fraction, 0);

      final none = TodayProgress.of(const [], today: today, isCompletedToday: (_) => false);
      expect(none.hasHabits, isFalse);
    });

    test("only habits due today are today's obligations", () {
      // today is a Friday.
      final fridays = habit('fri', schedule: HabitSchedule.weekdays({DateTime.friday}));
      final mondays = habit('mon', schedule: HabitSchedule.weekdays({DateTime.monday}));
      final weekly = habit('w', schedule: HabitSchedule.weeklyTarget(3));
      final progress = TodayProgress.of(
        [habit('d'), fridays, mondays, weekly],
        today: today,
        isCompletedToday: (id) => id == 'd' || id == 'fri' || id == 'mon',
        weekTargetReached: (habit) => false,
      );
      expect(progress.scheduled.map((h) => h.id), ['d', 'fri']);
      expect(progress.otherDays.map((h) => h.id), ['mon']);
      expect(progress.weekly.map((h) => h.id), ['w']);
      expect(progress.allDone, isTrue, reason: 'an open weekly goal does not hold back today');
      expect(progress.weeklyReached, 0);
    });

    test('a day with only weekly goals and days off has nothing due, but has habits', () {
      final progress = TodayProgress.of(
        [
          habit('w', schedule: HabitSchedule.weeklyTarget(2)),
          habit('mon', schedule: HabitSchedule.weekdays({DateTime.monday})),
        ],
        today: today,
        isCompletedToday: (_) => false,
        weekTargetReached: (habit) => true,
      );
      expect(progress.total, 0);
      expect(progress.hasHabits, isTrue);
      expect(progress.allDone, isFalse);
      expect(progress.weeklyReached, 1);
    });
  });

  group('HabitStatsBloc completion', () {
    late FakeStatsRepository repository;
    late HabitStatsBloc bloc;

    setUp(() async {
      repository = FakeStatsRepository();
      bloc = HabitStatsBloc(repository, now: () => today.toDateTime().add(const Duration(hours: 12)))
        ..add(HabitsStatsInitialLoad());
      await pumpEventQueue();
    });

    tearDown(() async {
      await bloc.close();
      await repository.dispose();
    });

    test('a repeated request for the same state writes once', () async {
      bloc
        ..add(HabitCompletionToggled('a', completed: true))
        ..add(HabitCompletionToggled('a', completed: true));
      await pumpEventQueue();
      expect(repository.writes, ['a:true']);
      expect((bloc.state as HabitStatsLoaded).isCompletedToday('a'), isTrue);
    });

    test("undo removes today's mark", () async {
      bloc.add(HabitCompletionToggled('a', completed: true));
      await pumpEventQueue();
      bloc.add(HabitCompletionToggled('a', completed: false));
      await pumpEventQueue();
      expect(repository.writes, ['a:true', 'a:false']);
      expect((bloc.state as HabitStatsLoaded).isCompletedToday('a'), isFalse);
    });

    test('a failed write is reported for that habit and nothing is marked', () async {
      repository.fail = true;
      bloc.add(HabitCompletionToggled('a', completed: true));
      final failed = await bloc.stream.firstWhere((s) => s is HabitStatsLoaded && s.failedHabitId != null);
      expect((failed as HabitStatsLoaded).failedHabitId, 'a');
      expect(failed.isCompletedToday('a'), isFalse);
    });
  });

  group('HabitsBloc', () {
    late FakeHabitRepository repository;
    late HabitsBloc bloc;

    Future<void> start(List<dynamic> habits) async {
      repository = FakeHabitRepository(habits.cast());
      bloc = HabitsBloc(repository);
      await pumpEventQueue();
    }

    tearDown(() async {
      await bloc.close();
      await repository.dispose();
    });

    test('the description is optional and inputs are trimmed', () async {
      await start(const []);
      bloc.add(AddHabit(title: '  Read  ', description: '   ', categoryKey: 'education', emojiIcon: ' 📚 '));
      await pumpEventQueue();
      final added = repository.habits.single;
      expect(added.title, 'Read');
      expect(added.description, isNull);
      expect(added.icon, '📚');
    });

    test('editing keeps the id and paused state and changes the icon', () async {
      await start([habit('a', active: false)]);
      bloc.add(UpdateHabit('a', 'Walk', 'Every evening', 'sport', '🚶'));
      await pumpEventQueue();
      final edited = repository.habits.single;
      expect(edited.id, 'a');
      expect(edited.isActive, isFalse);
      expect(
          (edited.title, edited.description, edited.categoryId, edited.icon), ('Walk', 'Every evening', 'sport', '🚶'));
    });

    test('a second delete of the same habit does nothing', () async {
      await start([habit('a')]);
      bloc.add(DeleteHabit('a'));
      await pumpEventQueue();
      bloc.add(DeleteHabit('a'));
      await pumpEventQueue();
      expect(repository.log.where((e) => e == 'delete'), hasLength(1));
    });

    test('a failed write names the operation', () async {
      await start([habit('a')]);
      repository.failures.add('update');
      bloc.add(UpdateHabit('a', 'X', ''));
      final failure = await bloc.stream.firstWhere((s) => s is HabitsOperationFailure);
      expect((failure as HabitsOperationFailure).operation, HabitOperation.update);
      expect(repository.habits.single.title, 'Habit a', reason: 'nothing changed');
    });

    group('schedule changes', () {
      Future<void> startWith(Habit initial) async {
        repository = FakeHabitRepository([initial]);
        bloc = HabitsBloc(repository, today: () => today);
        await pumpEventQueue();
      }

      test('a new habit keeps its schedule', () async {
        await start(const []);
        bloc.add(AddHabit(
          title: 'Run',
          description: '',
          categoryKey: 'sport',
          emojiIcon: '🏃',
          schedule: HabitSchedule.weeklyTarget(3),
        ));
        await pumpEventQueue();
        expect(repository.habits.single.schedule, HabitSchedule.weeklyTarget(3));
        expect(repository.habits.single.streakResetOn, isNull);
      });

      test('a confirmed type change saves the schedule and resets the streak from today', () async {
        await startWith(habit('a'));
        bloc.add(UpdateHabit('a', 'Habit a', '', null, null, HabitSchedule.weeklyTarget(3), true));
        await pumpEventQueue();
        final edited = repository.habits.single;
        expect(edited.schedule, HabitSchedule.weeklyTarget(3));
        expect(edited.streakResetOn, today);
      });

      test('an unconfirmed type change is refused and nothing is saved', () async {
        await startWith(habit('a'));
        bloc.add(UpdateHabit('a', 'Changed', '', null, null, HabitSchedule.weeklyTarget(3)));
        final failure = await bloc.stream.firstWhere((s) => s is HabitsOperationFailure);
        expect((failure as HabitsOperationFailure).operation, HabitOperation.update);
        expect(repository.log, isNot(contains('update')));
        expect(repository.habits.single, habit('a'));
      });

      test('unrelated edits keep the schedule and the reset day', () async {
        final resetOn = today.addDays(-10);
        final initial = habit('a', schedule: HabitSchedule.weeklyTarget(2), streakResetOn: resetOn);
        await startWith(initial);
        bloc.add(UpdateHabit('a', 'Renamed', 'New text', 'sport', '🚶', HabitSchedule.weeklyTarget(2)));
        await pumpEventQueue();
        final edited = repository.habits.single;
        expect(edited.title, 'Renamed');
        expect((edited.schedule, edited.streakResetOn), (HabitSchedule.weeklyTarget(2), resetOn));
      });

      test('changing parameters within a type does not reset the streak', () async {
        await startWith(habit('a', schedule: HabitSchedule.weekdays({DateTime.monday})));
        final next = HabitSchedule.weekdays({DateTime.monday, DateTime.thursday});
        // Even if a reset is requested, the type did not change.
        bloc.add(UpdateHabit('a', 'Habit a', '', null, null, next, true));
        await pumpEventQueue();
        final edited = repository.habits.single;
        expect(edited.schedule, next);
        expect(edited.streakResetOn, isNull);
      });

      test('a later confirmed type change moves the reset day', () async {
        await startWith(habit('a', schedule: HabitSchedule.weeklyTarget(2), streakResetOn: today.addDays(-30)));
        bloc.add(UpdateHabit('a', 'Habit a', '', null, null, HabitSchedule.daily, true));
        await pumpEventQueue();
        expect(repository.habits.single.streakResetOn, today);
      });
    });

    test('a failed initial load is its own state', () async {
      repository = FakeHabitRepository()..failLoad = true;
      bloc = HabitsBloc(repository);
      await pumpEventQueue();
      expect(bloc.state, isA<HabitsLoadFailure>());
    });
  });
}
