import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/social/domain/friend_action.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

sealed class PublicProfileEvent {
  const PublicProfileEvent();
}

final class PublicProfileRequested extends PublicProfileEvent {
  const PublicProfileRequested();
}

final class PublicProfileActionRequested extends PublicProfileEvent {
  final FriendAction action;

  const PublicProfileActionRequested(this.action);
}

enum PublicProfileStatus { loading, ready, failure }

@immutable
final class PublicProfileState {
  final PublicProfileStatus status;
  final PublicProfile? profile;
  final SocialFailure? failure;
  final bool isBusy;
  final SocialNotice? notice;

  const PublicProfileState({
    this.status = PublicProfileStatus.loading,
    this.profile,
    this.failure,
    this.isBusy = false,
    this.notice,
  });

  PublicProfileState copyWith({
    PublicProfileStatus? status,
    PublicProfile? profile,
    SocialFailure? Function()? failure,
    bool? isBusy,
    SocialNotice? notice,
  }) =>
      PublicProfileState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        failure: failure != null ? failure() : this.failure,
        isBusy: isBusy ?? this.isBusy,
        notice: notice,
      );
}

/// Another user's public profile and the relationship actions available on it.
class PublicProfileBloc extends Bloc<PublicProfileEvent, PublicProfileState> {
  final SocialRepository _repository;
  final String publicId;

  PublicProfileBloc(this._repository, {required this.publicId}) : super(const PublicProfileState()) {
    on<PublicProfileRequested>(_onRequested, transformer: restartable());
    on<PublicProfileActionRequested>(_onAction, transformer: droppable());
  }

  Future<void> _onRequested(PublicProfileRequested event, Emitter<PublicProfileState> emit) async {
    emit(state.copyWith(status: PublicProfileStatus.loading));
    try {
      final profile = await _repository.publicProfile(publicId);
      emit(state.copyWith(status: PublicProfileStatus.ready, profile: profile, failure: () => null));
    } on SocialException catch (e) {
      emit(state.copyWith(status: PublicProfileStatus.failure, failure: () => e.failure));
    }
  }

  Future<void> _onAction(PublicProfileActionRequested event, Emitter<PublicProfileState> emit) async {
    final profile = state.profile;
    if (profile == null) return;
    emit(state.copyWith(isBusy: true));
    try {
      final relationship = await event.action.run(_repository, publicId);
      emit(state.copyWith(
        isBusy: false,
        profile: profile.withRelationship(relationship),
        notice: SocialNotice.done(event.action, relationship),
      ));
      // Statistics visibility may have changed (e.g. after becoming friends).
      add(const PublicProfileRequested());
    } on SocialException catch (e) {
      emit(state.copyWith(isBusy: false, notice: SocialNotice.failed(e.failure, action: event.action)));
      if (e.failure == SocialFailure.notFound) add(const PublicProfileRequested());
    }
  }
}
