import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';
import 'package:go_habit/feature/habits/bloc/habits_bloc.dart';
import 'package:mockito/mockito.dart';

// Моки блоков
class MockHabitsBloc extends Mock implements HabitsBloc {
  @override
  Stream<HabitsState> get stream => Stream.fromIterable([]);
}

class MockHabitStatsBloc extends Mock implements HabitStatsBloc {
  final _stateController = StreamController<HabitStatsState>.broadcast();
  final HabitStatsState _state;

  MockHabitStatsBloc([HabitStatsState? state]) : _state = state ?? loadedStats() {
    _stateController.add(_state);
  }

  @override
  HabitStatsState get state => _state;

  @override
  Stream<HabitStatsState> get stream => _stateController.stream;

  @override
  Future<void> close() {
    _stateController.close();
    return Future.value();
  }
}

/// Состояние статистики с фиксированным «сегодня», чтобы снимки не зависели от даты запуска.
HabitStatsLoaded loadedStats({Map<String, List<CalendarDay>> completedDays = const {}, CalendarDay? today}) {
  return HabitStatsLoaded(
    [
      for (final MapEntry(key: habitId, value: days) in completedDays.entries)
        for (final day in days) HabitCompletionModel(id: '$habitId/$day', habitId: habitId, completedOn: day),
    ],
    today: today ?? CalendarDay(2023, 5, 15),
  );
}

/// Виджет для оборачивания тестируемого виджета в провайдеры блоков
class MockBlocWrapper extends StatelessWidget {
  final Widget child;
  final HabitStatsState? statsState;

  const MockBlocWrapper({
    required this.child,
    this.statsState,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HabitsBloc>.value(value: MockHabitsBloc()),
        BlocProvider<HabitStatsBloc>.value(value: MockHabitStatsBloc(statsState)),
      ],
      child: child,
    );
  }
}
