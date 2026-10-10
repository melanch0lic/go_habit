import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/utils/calendar_day.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/domain/repositories/community_repository.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';

part 'community_detail_event.dart';
part 'community_detail_state.dart';

/// One community: its template, the user's membership, the weekly ranking and the
/// member count.
class CommunityDetailBloc extends Bloc<CommunityDetailEvent, CommunityDetailState> {
  final CommunityRepository _repository;
  final CalendarDay Function() _today;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  CommunityDetailBloc(this._repository, {required String templateId, CalendarDay Function()? today})
      : _today = today ?? CalendarDay.today,
        super(CommunityDetailState(templateId: templateId)) {
    on<CommunityDetailStarted>(_onStarted);
    on<CommunityLeaderboardRefreshed>(_onLeaderboardRefreshed, transformer: restartable());
    // One action at a time; taps while it runs are dropped.
    on<_CommunityAction>(_onAction, transformer: droppable());
    on<_MembershipChanged>((event, emit) => emit(state.copyWith(membership: () => event.membership)));
  }

  Future<void> _onStarted(CommunityDetailStarted event, Emitter<CommunityDetailState> emit) async {
    if (_subscriptions.isEmpty) {
      _subscriptions
        ..add(_repository
            .watchMemberships()
            .listen((memberships) => add(_MembershipChanged(memberships[state.templateId]))))
        // Completions that just reached the server change the ranking.
        ..add(_repository.serverDataChanged.listen((_) => add(const CommunityLeaderboardRefreshed())));
    }

    emit(state.copyWith(templateStatus: LoadStatus.loading));
    try {
      final template = await _repository.getTemplate(state.templateId);
      emit(state.copyWith(
        template: template,
        templateStatus: template == null ? LoadStatus.failure : LoadStatus.ready,
        templateFailure: () => template == null ? CommunityFailure.unknown : null,
      ));
    } on CommunityException catch (e) {
      emit(state.copyWith(templateStatus: LoadStatus.failure, templateFailure: () => e.failure));
      return;
    }
    add(const CommunityLeaderboardRefreshed());
  }

  Future<void> _onLeaderboardRefreshed(CommunityLeaderboardRefreshed event, Emitter<CommunityDetailState> emit) async {
    if (state.template == null) return;
    emit(state.copyWith(leaderboardStatus: LoadStatus.loading));
    final unsynced = await _repository.hasUnsyncedChanges();
    final memberCount = _repository.memberCount(state.templateId);
    try {
      final leaderboard = await _repository.leaderboard(state.templateId, today: _today());
      emit(state.copyWith(
        leaderboardStatus: LoadStatus.ready,
        leaderboard: () => leaderboard,
        leaderboardFailure: () => null,
        hasUnsyncedChanges: unsynced,
      ));
    } on CommunityException catch (e) {
      emit(state.copyWith(
        leaderboardStatus: LoadStatus.failure,
        leaderboardFailure: () => e.failure,
        hasUnsyncedChanges: unsynced,
      ));
    }
    // Unknown (null) rather than stale when it cannot be loaded.
    final count = await memberCount;
    emit(state.copyWith(memberCount: () => count));
  }

  Future<void> _onAction(_CommunityAction event, Emitter<CommunityDetailState> emit) async {
    final template = state.template;
    if (template == null) return;
    // Read before the request: the membership stream may update while it runs.
    final wasMember = state.isMember;
    emit(state.copyWith(isBusy: true));
    try {
      final outcome = switch (event) {
        CommunityJoinRequested() => await _repository.join(template.id).then((_) => CommunityOutcome.joined),
        RankedHabitRequested(:final title, :final description, :final schedule) => await _repository
            .joinWithRankedHabit(template, title: title, description: description, schedule: schedule)
            .then((_) => wasMember ? CommunityOutcome.rankedHabitCreated : CommunityOutcome.joinedRanked),
        CommunityLeaveRequested() => await _repository.leave(template.id).then((_) => CommunityOutcome.left),
      };
      emit(state.copyWith(isBusy: false, notice: () => CommunityNotice(outcome: outcome)));
      add(const CommunityLeaderboardRefreshed());
    } on CommunityException catch (e) {
      emit(state.copyWith(
        isBusy: false,
        notice: () => CommunityNotice(outcome: CommunityOutcome.failed, failure: e.failure),
      ));
    } on Object {
      emit(state.copyWith(
        isBusy: false,
        notice: () => const CommunityNotice(outcome: CommunityOutcome.failed, failure: CommunityFailure.unknown),
      ));
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
