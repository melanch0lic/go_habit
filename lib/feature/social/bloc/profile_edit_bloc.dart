import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/domain/nickname_rules.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';

sealed class ProfileEditEvent {
  const ProfileEditEvent();
}

final class NicknameEdited extends ProfileEditEvent {
  final String nickname;

  const NicknameEdited(this.nickname);
}

final class AvatarSelected extends ProfileEditEvent {
  /// Null selects the generated default avatar.
  final String? avatar;

  const AvatarSelected(this.avatar);
}

final class ProfileEditSubmitted extends ProfileEditEvent {
  final String bio;

  const ProfileEditSubmitted({required this.bio});
}

final class _AvailabilityChecked extends ProfileEditEvent {
  final String nickname;

  const _AvailabilityChecked(this.nickname);
}

/// What is known about the typed nickname.
enum NicknameCheck { unchanged, invalid, checking, available, taken, unknown }

@immutable
final class ProfileEditState {
  final String nickname;
  final String? avatar;
  final NicknameCheck check;

  /// Set when [check] is [NicknameCheck.invalid].
  final NicknameError? error;
  final bool isSaving;

  /// The saved profile, once the server confirmed it.
  final MyProfile? saved;

  /// A failed save, shown once.
  final SocialFailure? failure;

  const ProfileEditState({
    required this.nickname,
    this.avatar,
    this.check = NicknameCheck.unchanged,
    this.error,
    this.isSaving = false,
    this.saved,
    this.failure,
  });

  /// Saving is possible unless the nickname is known to be unusable or still checked.
  bool get canSave =>
      !isSaving &&
      NicknameRules.validate(nickname) == null &&
      check != NicknameCheck.taken &&
      check != NicknameCheck.invalid &&
      check != NicknameCheck.checking;

  ProfileEditState copyWith({
    String? nickname,
    String? Function()? avatar,
    NicknameCheck? check,
    NicknameError? Function()? error,
    bool? isSaving,
    MyProfile? saved,
    SocialFailure? failure,
  }) =>
      ProfileEditState(
        nickname: nickname ?? this.nickname,
        avatar: avatar != null ? avatar() : this.avatar,
        check: check ?? this.check,
        error: error != null ? error() : this.error,
        isSaving: isSaving ?? this.isSaving,
        saved: saved ?? this.saved,
        failure: failure,
      );
}

/// Editing the public profile, with a debounced nickname availability check.
class ProfileEditBloc extends Bloc<ProfileEditEvent, ProfileEditState> {
  final SocialRepository _repository;
  final String? _currentNickname;
  final Duration _debounce;

  ProfileEditBloc(this._repository, {MyProfile? profile, Duration debounce = const Duration(milliseconds: 400)})
      : _currentNickname = profile?.nickname,
        _debounce = debounce,
        super(ProfileEditState(nickname: profile?.nickname ?? '', avatar: profile?.avatar)) {
    on<NicknameEdited>(_onNicknameEdited);
    // Only the latest typed value is checked; earlier checks are cancelled.
    on<_AvailabilityChecked>(_onAvailabilityChecked, transformer: restartable());
    on<AvatarSelected>((event, emit) => emit(state.copyWith(avatar: () => event.avatar)));
    on<ProfileEditSubmitted>(_onSubmitted, transformer: droppable());
  }

  void _onNicknameEdited(NicknameEdited event, Emitter<ProfileEditState> emit) {
    final nickname = event.nickname;
    final error = NicknameRules.validate(nickname);
    if (error != null) {
      emit(state.copyWith(nickname: nickname, check: NicknameCheck.invalid, error: () => error));
      add(_AvailabilityChecked(nickname)); // cancels a check in flight
      return;
    }
    final current = _currentNickname;
    if (current != null && NicknameRules.same(nickname, current)) {
      emit(state.copyWith(nickname: nickname, check: NicknameCheck.unchanged, error: () => null));
      add(_AvailabilityChecked(nickname));
      return;
    }
    emit(state.copyWith(nickname: nickname, check: NicknameCheck.checking, error: () => null));
    add(_AvailabilityChecked(nickname));
  }

  Future<void> _onAvailabilityChecked(_AvailabilityChecked event, Emitter<ProfileEditState> emit) async {
    if (state.check != NicknameCheck.checking) return;
    await Future<void>.delayed(_debounce);
    // A newer value arrived during the pause: its own check will run instead.
    if (emit.isDone || state.nickname != event.nickname) return;
    try {
      final status = await _repository.nicknameStatus(event.nickname);
      if (state.nickname != event.nickname) return;
      emit(state.copyWith(
        check: switch (status) {
          NicknameStatus.available => NicknameCheck.available,
          NicknameStatus.taken => NicknameCheck.taken,
          NicknameStatus.invalid => NicknameCheck.invalid,
        },
      ));
    } on SocialException {
      // Unknown, not unavailable: the server decides on save.
      if (state.nickname == event.nickname) emit(state.copyWith(check: NicknameCheck.unknown));
    }
  }

  Future<void> _onSubmitted(ProfileEditSubmitted event, Emitter<ProfileEditState> emit) async {
    if (!state.canSave) return;
    emit(state.copyWith(isSaving: true));
    try {
      final saved = await _repository.updateProfile(nickname: state.nickname, bio: event.bio, avatar: state.avatar);
      emit(state.copyWith(isSaving: false, saved: saved));
    } on SocialException catch (e) {
      emit(state.copyWith(
        isSaving: false,
        failure: e.failure,
        // Someone else claimed the nickname between the check and the save.
        check: e.failure == SocialFailure.nicknameTaken ? NicknameCheck.taken : null,
      ));
    }
  }
}
