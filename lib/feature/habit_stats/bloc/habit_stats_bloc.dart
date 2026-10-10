import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habit_stats/domain/models/habit_completion.dart';
import 'package:go_habit/feature/habit_stats/domain/repositories/habit_stats_repository.dart';
import 'package:go_habit/feature/habit_stats/domain/streak.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:meta/meta.dart';

part 'habit_stats_event.dart';
part 'habit_stats_state.dart';

class HabitStatsBloc extends Bloc<HabitStatsEvent, HabitStatsState> {
  final HabitStatsRepository _repository;
  final DateTime Function() _now;
  Timer? _midnightTimer;
  List<HabitCompletionModel> _completions = const [];

  HabitStatsBloc(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(HabitStatsInitial()) {
    on<HabitsStatsInitialLoad>(_onInitialLoad, transformer: restartable());
    // Sequential: each request sees the result of the previous one.
    on<HabitCompletionToggled>(_onToggled, transformer: sequential());
    on<_HabitStatsDayChanged>(_onDayChanged);
  }

  CalendarDay get _today => CalendarDay.fromDateTime(_now());

  Future<void> _onInitialLoad(HabitsStatsInitialLoad event, Emitter<HabitStatsState> emit) async {
    emit(HabitStatsLoading());
    _scheduleMidnightRefresh();
    await emit.forEach<List<HabitCompletionModel>>(
      _repository.watchCompletions(),
      onData: (completions) {
        _completions = completions;
        return HabitStatsLoaded(completions, today: _today);
      },
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return HabitStatsError();
      },
    );
  }

  Future<void> _onToggled(HabitCompletionToggled event, Emitter<HabitStatsState> emit) async {
    final today = _today;
    final completed = _completions.any((c) => c.habitId == event.habitId && c.completedOn == today);
    final target = event.completed ?? !completed;
    // Already in the requested state (e.g. a repeated tap): nothing to write.
    if (target == completed) return;
    try {
      await _repository.setCompleted(habitId: event.habitId, day: today, completed: target);
      // The watch stream emits the new state.
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (state is HabitStatsLoaded) {
        emit(HabitStatsLoaded(_completions, today: today, failedHabitId: event.habitId));
      }
    }
  }

  void _onDayChanged(_HabitStatsDayChanged event, Emitter<HabitStatsState> emit) {
    if (state is HabitStatsLoaded) emit(HabitStatsLoaded(_completions, today: _today));
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = _now();
    final nextDay = _today.addDays(1).toDateTime();
    _midnightTimer = Timer(nextDay.difference(now) + const Duration(seconds: 1), () => add(_HabitStatsDayChanged()));
  }

  @override
  Future<void> close() {
    _midnightTimer?.cancel();
    return super.close();
  }
}
