import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/domain/repositories/habit_repository.dart';

part 'habits_event.dart';
part 'habits_state.dart';

class HabitsBloc extends Bloc<HabitsEvent, HabitsState> {
  final HabitRepository _habitRepository;
  final CalendarDay Function() _today;
  StreamSubscription<List<Habit>>? _subscription;

  HabitsBloc(this._habitRepository, {CalendarDay Function()? today})
      : _today = today ?? CalendarDay.today,
        super(HabitsInitial()) {
    // Writes read `state.habits`; handling one event at a time avoids acting on stale state.
    on<HabitsEvent>((event, emit) async {
      switch (event) {
        case InitializeHabits():
          await _onInitializeHabits(event, emit);
        case LoadHabits():
          await _onLoadHabits(event, emit);
        case AddHabit():
          await _onAddHabit(event, emit);
        case UpdateHabit():
          await _onUpdateHabit(event, emit);
        case DeleteHabit():
          await _onDeleteHabit(event, emit);
        case ToggleActiveHabit():
          await _onToggleHabitActive(event, emit);
      }
    }, transformer: sequential());

    _subscription = _habitRepository.watchHabits().listen((habits) {
      add(LoadHabits(habits));
    });

    add(InitializeHabits());
  }

  Future<void> _onToggleHabitActive(ToggleActiveHabit event, Emitter<HabitsState> emit) async {
    try {
      final habit = state.habits.firstWhere((element) => element.id == event.id);
      final toggleHabit = habit.copyWith(isActive: !habit.isActive);
      await _habitRepository.updateHabit(toggleHabit);
      emit(HabitsOperationSuccess(message: 'Habit is toggled', habits: state.habits));
    } catch (error) {
      emit(HabitsOperationFailure(
          error: error.toString(), habits: state.habits, operation: HabitOperation.toggleActive));
    }
  }

  Future<void> _onInitializeHabits(InitializeHabits event, Emitter<HabitsState> emit) async {
    try {
      final habits = await _habitRepository.getHabits();
      emit(HabitsLoadSuccess(habits));
    } catch (error) {
      emit(HabitsLoadFailure(error.toString()));
    }
  }

  Future<void> _onLoadHabits(LoadHabits event, Emitter<HabitsState> emit) async {
    emit(HabitsLoadSuccess(event.habits));
  }

  Future<void> _onAddHabit(AddHabit event, Emitter<HabitsState> emit) async {
    final title = event.title.trim();
    final description = event.description.trim();
    // The description is optional, as on the server.
    if (title.isEmpty || event.emojiIcon.trim().isEmpty) {
      emit(HabitsOperationFailure(
          error: 'Title and icon are required', habits: state.habits, operation: HabitOperation.add));
      return;
    }

    try {
      final habit = Habit(
        title: title,
        description: description.isEmpty ? null : description,
        categoryId: event.categoryKey,
        icon: event.emojiIcon.trim(),
        schedule: event.schedule,
      );
      await _habitRepository.addHabit(habit);
      emit(HabitsOperationSuccess(message: 'Habit is added', habits: state.habits));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(HabitsOperationFailure(error: error.toString(), habits: state.habits, operation: HabitOperation.add));
    }
  }

  Future<void> _onUpdateHabit(UpdateHabit event, Emitter<HabitsState> emit) async {
    try {
      final current = state.habits.firstWhere((element) => element.id == event.id);
      final schedule = event.schedule;
      // A type change resets the streak only when confirmed (resetStreak); the new
      // schedule and the reset day are saved together, so they sync together.
      final typeChanged = schedule != null && schedule.type != current.schedule.type;
      if (typeChanged && !event.resetStreak) {
        // Mixing the old history with another schedule's rules would be wrong.
        emit(HabitsOperationFailure(
          error: 'A schedule type change must be confirmed',
          habits: state.habits,
          operation: HabitOperation.update,
        ));
        return;
      }
      final editedHabit = current.copyWith(
        title: event.title.trim(),
        // An empty description clears it.
        description: event.description.trim(),
        categoryId: event.categoryId,
        icon: event.icon?.trim(),
        schedule: schedule,
        streakResetOn: typeChanged && event.resetStreak ? _today() : null,
      );
      await _habitRepository.updateHabit(editedHabit);
      emit(HabitsOperationSuccess(message: 'Habit is updated', habits: state.habits));
    } catch (error) {
      emit(HabitsOperationFailure(error: error.toString(), habits: state.habits, operation: HabitOperation.update));
    }
  }

  Future<void> _onDeleteHabit(DeleteHabit event, Emitter<HabitsState> emit) async {
    // Already gone (e.g. a repeated confirmation): nothing to do.
    if (!state.habits.any((habit) => habit.id == event.id)) return;
    try {
      await _habitRepository.deleteHabit(event.id);
      emit(HabitsOperationSuccess(message: 'Habit is deleted', habits: state.habits));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(HabitsOperationFailure(error: error.toString(), habits: state.habits, operation: HabitOperation.delete));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
