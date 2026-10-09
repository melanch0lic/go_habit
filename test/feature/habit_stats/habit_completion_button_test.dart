import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';
import 'package:go_habit/feature/habit_stats/widget/habit_completion_button.dart';
import 'package:go_habit/l10n/app_localizations.dart';

import '../../helpers/haptics_recorder.dart';

class _FakeStatsRepository implements HabitStatsRepository {
  final completions = StreamController<List<HabitCompletionModel>>.broadcast();
  final calls = <bool>[];
  Error? failWith;

  Future<void> dispose() => completions.close();

  @override
  Stream<List<HabitCompletionModel>> watchCompletions() => completions.stream;

  @override
  Future<void> setCompleted({required String habitId, required CalendarDay day, required bool completed}) async {
    if (failWith != null) throw failWith!;
    calls.add(completed);
  }
}

void main() {
  final today = CalendarDay(2026, 10, 9);
  late _FakeStatsRepository repository;
  late HabitStatsBloc bloc;
  late List<String> haptics;

  final done = [HabitCompletionModel(id: 'c', habitId: 'h1', completedOn: today)];

  /// The bloc owns a midnight timer, which must be cancelled before the test body
  /// ends (widget tests verify that no timers are pending before tear-down).
  void testButton(String description, Future<void> Function(WidgetTester tester) body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      // close() cancels the timer synchronously; awaiting it would need real time.
      unawaited(bloc.close());
      unawaited(repository.dispose());
      await tester.pump();
    });
  }

  Future<void> pump(WidgetTester tester) async {
    haptics = recordHaptics(tester);
    repository = _FakeStatsRepository();
    bloc = HabitStatsBloc(repository, now: () => DateTime(2026, 10, 9, 12))..add(HabitsStatsInitialLoad());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: BlocProvider.value(
              value: bloc,
              child: const HabitCompletionButton(habitId: 'h1', color: Colors.green, iconColor: Colors.white),
            ),
          ),
        ),
      ),
    );
    repository.completions.add(const []);
    await tester.pumpAndSettle();
  }

  testButton('a tap toggles once; success feedback waits for the confirmed state', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(HabitCompletionButton));
    await tester.pump();

    expect(repository.calls, [true]);
    expect(haptics, isEmpty, reason: 'nothing is confirmed yet');
    expect(find.byIcon(Icons.check), findsOneWidget);

    repository.completions.add(done);
    await tester.pumpAndSettle();

    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testButton('a completion arriving from sync updates silently', (tester) async {
    await pump(tester);
    repository.completions.add(done);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(haptics, isEmpty);
  });

  testButton('undoing a completion gives no success feedback', (tester) async {
    await pump(tester);
    repository.completions.add(done);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HabitCompletionButton));
    await tester.pump();
    repository.completions.add(const []);
    await tester.pumpAndSettle();

    expect(repository.calls, [false]);
    expect(haptics, isEmpty);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testButton('a failed write shows no success', (tester) async {
    await pump(tester);
    repository.failWith = StateError('disk full');
    await tester.tap(find.byType(HabitCompletionButton));
    await tester.pumpAndSettle();

    expect(haptics, isEmpty);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testButton('screen readers get a label for the current action and can activate it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    expect(
      tester.getSemantics(find.byType(HabitCompletionButton)),
      containsSemantics(label: 'Mark as done for today', isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel('Mark as done for today'));
    await tester.pump();
    expect(repository.calls, [true]);
    semantics.dispose();
  });
}
