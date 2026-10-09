import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/initizialization/scopes/app_scope_container.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/bloc/profile_edit_bloc.dart';
import 'package:go_habit/feature/social/domain/nickname_rules.dart';
import 'package:go_habit/feature/social/domain/repositories/social_repository.dart';
import 'package:go_habit/feature/social/view/components/user_avatar.dart';
import 'package:go_habit/feature/social/view/social_texts.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

/// Editing the public profile: nickname, avatar and bio. With [isSetup] it is the
/// prompt shown to users without a nickname, which they may postpone.
class ProfileEditScreen extends StatelessWidget {
  final bool isSetup;

  const ProfileEditScreen({this.isSetup = false, super.key});

  @override
  Widget build(BuildContext context) => ScopeBuilder<AppScopeContainer>.withPlaceholder(
        builder: (context, scope) => ProfileEditView(repository: scope.socialRepository.get, isSetup: isSetup),
      );
}

/// [ProfileEditScreen] with its dependency passed in (used by tests).
class ProfileEditView extends StatelessWidget {
  final SocialRepository repository;
  final bool isSetup;
  final Duration debounce;

  const ProfileEditView({
    required this.repository,
    this.isSetup = false,
    this.debounce = const Duration(milliseconds: 400),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.read<MyProfileBloc>().state.profile;
    return BlocProvider(
      create: (_) => ProfileEditBloc(repository, profile: profile, debounce: debounce),
      child: _EditBody(isSetup: isSetup, initialBio: profile?.bio ?? ''),
    );
  }
}

class _EditBody extends StatefulWidget {
  final bool isSetup;
  final String initialBio;

  const _EditBody({required this.isSetup, required this.initialBio});

  @override
  State<_EditBody> createState() => _EditBodyState();
}

class _EditBodyState extends State<_EditBody> {
  late final _nickname = TextEditingController(text: context.read<ProfileEditBloc>().state.nickname);
  late final _bio = TextEditingController(text: widget.initialBio);

  static const _bioLength = 160;

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, ProfileEditState state) {
    final l10n = context.l10n;
    final saved = state.saved;
    if (saved != null) {
      AppHaptics.success();
      context.read<MyProfileBloc>().add(MyProfileReplaced(saved));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.social_profile_saved)));
      Navigator.of(context).maybePop();
      return;
    }
    if (state.failure case final failure?) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;

    return BlocConsumer<ProfileEditBloc, ProfileEditState>(
      listenWhen: (previous, current) => current.saved != null || current.failure != null,
      listener: _onState,
      builder: (context, state) {
        final bloc = context.read<ProfileEditBloc>();
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.isSetup ? l10n.social_setup_title : l10n.social_edit_profile),
            actions: [
              if (widget.isSetup)
                TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.auth_later)),
            ],
          ),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                if (widget.isSetup) ...[
                  Text(l10n.social_setup_subtitle, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  const SizedBox(height: 20),
                ],
                Center(child: UserAvatar(nickname: state.nickname, avatar: state.avatar, size: 96)),
                const SizedBox(height: 16),
                _AvatarPicker(
                  nickname: state.nickname,
                  selected: state.avatar,
                  onSelected: (avatar) => bloc.add(AvatarSelected(avatar)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nickname,
                  enabled: !state.isSaving,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_]')),
                    LengthLimitingTextInputFormatter(NicknameRules.maxLength),
                  ],
                  onChanged: (value) => bloc.add(NicknameEdited(value)),
                  decoration: InputDecoration(
                    labelText: l10n.social_nickname_label,
                    prefixText: '@',
                    border: const OutlineInputBorder(),
                    helperText: l10n.social_nickname_hint,
                    helperMaxLines: 2,
                    errorText: _nicknameError(state),
                    errorMaxLines: 2,
                    suffixIcon: _NicknameStatusIcon(check: state.check),
                  ),
                ),
                _NicknameStatusText(check: state.check),
                const SizedBox(height: 16),
                TextField(
                  controller: _bio,
                  enabled: !state.isSaving,
                  maxLength: _bioLength,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.social_bio_label, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                PressableScale(
                  enabled: state.canSave,
                  child: ElevatedButton(
                    onPressed: state.canSave ? () => bloc.add(ProfileEditSubmitted(bio: _bio.text)) : null,
                    child: state.isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.social_save),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _nicknameError(ProfileEditState state) {
    if (state.check == NicknameCheck.taken) return context.l10n.social_nickname_taken;
    final error = state.error;
    // Do not shout at an empty field before the user typed anything.
    if (error == null || (error == NicknameError.empty && state.nickname.isEmpty && _nickname.text.isEmpty)) {
      return null;
    }
    return error.message(context.l10n);
  }
}

class _NicknameStatusIcon extends StatelessWidget {
  final NicknameCheck check;

  const _NicknameStatusIcon({required this.check});

  @override
  Widget build(BuildContext context) => switch (check) {
        NicknameCheck.checking => const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        NicknameCheck.available => Icon(Icons.check_circle, color: context.theme.commonColors.green100),
        _ => const SizedBox.shrink(),
      };
}

class _NicknameStatusText extends StatelessWidget {
  final NicknameCheck check;

  const _NicknameStatusText({required this.check});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (check) {
      NicknameCheck.available => l10n.social_nickname_available,
      NicknameCheck.checking => l10n.social_nickname_checking,
      NicknameCheck.unknown => l10n.social_nickname_unchecked,
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 6),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: context.themeOf.textTheme.bodySmall?.copyWith(
            color: check == NicknameCheck.available ? context.theme.commonColors.green100 : null,
          ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final String nickname;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _AvatarPicker({required this.nickname, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final green = context.theme.commonColors.green100;

    Widget option({required String? key, required String label}) {
      final isSelected = selected == key;
      return Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (!isSelected) AppHaptics.selection();
            onSelected(key);
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? green : Colors.transparent, width: 2),
            ),
            child: UserAvatar(nickname: nickname, avatar: key, size: 44),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.social_avatar_label, style: context.themeOf.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            option(key: null, label: l10n.social_avatar_default),
            for (final preset in AvatarPreset.all) option(key: preset.key, label: preset.emoji),
          ],
        ),
      ],
    );
  }
}
