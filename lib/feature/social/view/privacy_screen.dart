import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/feature/social/bloc/my_profile_bloc.dart';
import 'package:go_habit/feature/social/domain/models/social.dart';
import 'package:go_habit/feature/social/view/social_texts.dart';

/// Who may see the profile statistics and the user's communities. Saved on the
/// server immediately; the selection only changes once the server confirmed it.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    return BlocConsumer<MyProfileBloc, MyProfileState>(
      listenWhen: (previous, current) => current.privacyFailure != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.privacyFailure!.message(l10n)))),
      builder: (context, state) {
        final profile = state.profile;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.social_privacy_title),
            actions: [
              if (state.isSavingPrivacy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
          body: profile == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    Text(l10n.social_privacy_intro, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                    const SizedBox(height: 16),
                    _VisibilityGroup(
                      title: l10n.social_privacy_stats,
                      hint: l10n.social_privacy_stats_hint,
                      value: profile.statsVisibility,
                      enabled: !state.isSavingPrivacy,
                      onChanged: (value) => context.read<MyProfileBloc>().add(
                            MyPrivacyChanged(stats: value, communities: profile.communitiesVisibility),
                          ),
                    ),
                    const SizedBox(height: 16),
                    _VisibilityGroup(
                      title: l10n.social_privacy_communities,
                      hint: l10n.social_privacy_communities_hint,
                      value: profile.communitiesVisibility,
                      enabled: !state.isSavingPrivacy,
                      onChanged: (value) => context.read<MyProfileBloc>().add(
                            MyPrivacyChanged(stats: profile.statsVisibility, communities: value),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.social_privacy_always_private, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                  ],
                ),
        );
      },
    );
  }
}

class _VisibilityGroup extends StatelessWidget {
  final String title;
  final String hint;
  final ProfileVisibility value;
  final bool enabled;
  final ValueChanged<ProfileVisibility> onChanged;

  const _VisibilityGroup({
    required this.title,
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodySmall),
          RadioGroup<ProfileVisibility>(
            groupValue: value,
            onChanged: (selected) {
              if (enabled && selected != null && selected != value) onChanged(selected);
            },
            child: Column(
              children: [
                for (final option in ProfileVisibility.values)
                  RadioListTile<ProfileVisibility>(
                    value: option,
                    enabled: enabled,
                    contentPadding: EdgeInsets.zero,
                    activeColor: context.theme.commonColors.green100,
                    title: Text(option.label(l10n)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
