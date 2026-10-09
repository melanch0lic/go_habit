import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/social/domain/friend_action.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

sealed class FriendsEvent {
  const FriendsEvent();
}

/// Loading or clearing; a newer one cancels the one in flight, so a late answer for a
/// previous account can never be shown.
sealed class _GraphEvent extends FriendsEvent {
  const _GraphEvent();
}

/// Loads or reloads friends and requests.
final class FriendsRequested extends _GraphEvent {
  const FriendsRequested();
}

/// The user signed out: nothing of their friends may remain visible.
final class FriendsReset extends _GraphEvent {
  const FriendsReset();
}

final class FriendSearchSubmitted extends FriendsEvent {
  final String nickname;

  const FriendSearchSubmitted(this.nickname);
}

final class FriendSearchCleared extends FriendsEvent {
  const FriendSearchCleared();
}

final class FriendActionRequested extends FriendsEvent {
  final FriendAction action;
  final String publicId;

  const FriendActionRequested(this.action, this.publicId);
}

final class _RemoteChanged extends _GraphEvent {
  const _RemoteChanged();
}

enum LoadState { initial, loading, ready, failure }

@immutable
final class FriendSearchState {
  final String query;
  final LoadState status;
  final List<UserSearchResult> results;
  final SocialFailure? failure;

  const FriendSearchState({
    this.query = '',
    this.status = LoadState.initial,
    this.results = const [],
    this.failure,
  });
}

@immutable
final class FriendsState {
  final LoadState status;
  final SocialGraph graph;
  final SocialFailure? failure;
  final FriendSearchState search;

  /// Users with an action in progress (their buttons are disabled).
  final Set<String> busy;
  final SocialNotice? notice;

  const FriendsState({
    this.status = LoadState.initial,
    this.graph = SocialGraph.empty,
    this.failure,
    this.search = const FriendSearchState(),
    this.busy = const {},
    this.notice,
  });

  int get incomingCount => graph.incoming.length;

  FriendsState copyWith({
    LoadState? status,
    SocialGraph? graph,
    SocialFailure? Function()? failure,
    FriendSearchState? search,
    Set<String>? busy,
    SocialNotice? notice,
  }) =>
      FriendsState(
        status: status ?? this.status,
        graph: graph ?? this.graph,
        failure: failure != null ? failure() : this.failure,
        search: search ?? this.search,
        busy: busy ?? this.busy,
        notice: notice,
      );
}

/// Friends, requests and nickname search. Lives above the main navigation so the
/// profile tab can show the number of incoming requests.
class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  final SocialRepository _repository;
  StreamSubscription<void>? _changes;

  FriendsBloc(this._repository) : super(const FriendsState()) {
    on<_GraphEvent>(_onGraph, transformer: restartable());
    on<FriendSearchSubmitted>(_onSearch, transformer: restartable());
    on<FriendSearchCleared>((event, emit) => emit(state.copyWith(search: const FriendSearchState())));
    // Actions for different users may run side by side; one user's are serialized by [busy].
    on<FriendActionRequested>(_onAction, transformer: concurrent());

    // Actions taken elsewhere (e.g. on a profile screen) change the lists too.
    _changes = _repository.changes.listen((_) => add(const _RemoteChanged()));
  }

  Future<void> _onGraph(_GraphEvent event, Emitter<FriendsState> emit) async {
    if (event is FriendsReset) return emit(const FriendsState());
    emit(state.copyWith(status: LoadState.loading));
    try {
      final graph = await _repository.loadGraph();
      emit(state.copyWith(status: LoadState.ready, graph: graph, failure: () => null));
    } on SocialException catch (e) {
      emit(state.copyWith(status: LoadState.failure, failure: () => e.failure));
    }
  }

  Future<void> _onSearch(FriendSearchSubmitted event, Emitter<FriendsState> emit) async {
    final query = event.nickname.trim();
    if (query.isEmpty) {
      emit(state.copyWith(search: const FriendSearchState()));
      return;
    }
    emit(state.copyWith(search: FriendSearchState(query: query, status: LoadState.loading)));
    try {
      final results = await _repository.search(query);
      emit(state.copyWith(search: FriendSearchState(query: query, status: LoadState.ready, results: results)));
    } on SocialException catch (e) {
      emit(state.copyWith(search: FriendSearchState(query: query, status: LoadState.failure, failure: e.failure)));
    }
  }

  Future<void> _onAction(FriendActionRequested event, Emitter<FriendsState> emit) async {
    if (state.busy.contains(event.publicId)) return;
    emit(state.copyWith(busy: {...state.busy, event.publicId}));
    try {
      final relationship = await event.action.run(_repository, event.publicId);
      emit(state.copyWith(
        busy: {...state.busy}..remove(event.publicId),
        search: _withRelationship(event.publicId, relationship),
        notice: SocialNotice.done(event.action, relationship),
      ));
    } on SocialException catch (e) {
      emit(state.copyWith(
        busy: {...state.busy}..remove(event.publicId),
        notice: SocialNotice.failed(e.failure, action: event.action),
      ));
    }
  }

  /// Search results show the relationship the server just reported.
  FriendSearchState _withRelationship(String publicId, Relationship relationship) {
    final search = state.search;
    return FriendSearchState(
      query: search.query,
      status: search.status,
      failure: search.failure,
      results: [
        for (final result in search.results)
          result.user.publicId == publicId ? UserSearchResult(user: result.user, relationship: relationship) : result,
      ],
    );
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
