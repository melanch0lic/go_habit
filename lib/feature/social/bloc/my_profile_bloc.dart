import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

sealed class MyProfileEvent {
  const MyProfileEvent();
}

/// Loading or clearing; a newer one cancels the one in flight, so a late answer for a
/// previous account can never be shown.
sealed class _SessionEvent extends MyProfileEvent {
  const _SessionEvent();
}

final class MyProfileRequested extends _SessionEvent {
  const MyProfileRequested();
}

/// The user signed out: nothing of their profile may remain visible.
final class MyProfileReset extends _SessionEvent {
  const MyProfileReset();
}

/// The profile was saved elsewhere (the edit screen).
final class MyProfileReplaced extends MyProfileEvent {
  final MyProfile profile;

  const MyProfileReplaced(this.profile);
}

final class MyPrivacyChanged extends MyProfileEvent {
  final ProfileVisibility stats;
  final ProfileVisibility communities;

  const MyPrivacyChanged({required this.stats, required this.communities});
}

enum MyProfileStatus { initial, loading, ready, failure }

@immutable
final class MyProfileState {
  final MyProfileStatus status;
  final MyProfile? profile;
  final SocialFailure? failure;
  final bool isSavingPrivacy;

  /// A failed privacy change, shown once.
  final SocialFailure? privacyFailure;

  const MyProfileState({
    this.status = MyProfileStatus.initial,
    this.profile,
    this.failure,
    this.isSavingPrivacy = false,
    this.privacyFailure,
  });

  /// Known to lack a nickname (not just "not loaded yet").
  bool get needsNickname => profile != null && !profile!.hasNickname;

  MyProfileState copyWith({
    MyProfileStatus? status,
    MyProfile? profile,
    SocialFailure? Function()? failure,
    bool? isSavingPrivacy,
    SocialFailure? privacyFailure,
  }) =>
      MyProfileState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        failure: failure != null ? failure() : this.failure,
        isSavingPrivacy: isSavingPrivacy ?? this.isSavingPrivacy,
        privacyFailure: privacyFailure,
      );
}

/// The signed-in user's public profile, shared by the profile screen, the nickname
/// prompt and the friends section.
class MyProfileBloc extends Bloc<MyProfileEvent, MyProfileState> {
  final SocialRepository _repository;

  MyProfileBloc(this._repository) : super(const MyProfileState()) {
    on<_SessionEvent>(_onSession, transformer: restartable());
    on<MyProfileReplaced>((event, emit) => emit(state.copyWith(status: MyProfileStatus.ready, profile: event.profile)));
    on<MyPrivacyChanged>(_onPrivacyChanged, transformer: droppable());
  }

  Future<void> _onSession(_SessionEvent event, Emitter<MyProfileState> emit) async {
    if (event is MyProfileReset) return emit(const MyProfileState());
    emit(state.copyWith(status: MyProfileStatus.loading));
    try {
      final profile = await _repository.loadMyProfile();
      emit(state.copyWith(status: MyProfileStatus.ready, profile: profile, failure: () => null));
    } on SocialException catch (e) {
      emit(state.copyWith(status: MyProfileStatus.failure, failure: () => e.failure));
    }
  }

  Future<void> _onPrivacyChanged(MyPrivacyChanged event, Emitter<MyProfileState> emit) async {
    emit(state.copyWith(isSavingPrivacy: true));
    try {
      final profile = await _repository.updatePrivacy(stats: event.stats, communities: event.communities);
      emit(state.copyWith(profile: profile, isSavingPrivacy: false));
    } on SocialException catch (e) {
      emit(state.copyWith(isSavingPrivacy: false, privacyFailure: e.failure));
    }
  }
}
