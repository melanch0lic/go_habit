import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_section.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart';
import 'package:go_habit/feature/auth/view/welcome_screen.dart';
import 'package:go_habit/feature/profile/view/privacy_policy_screen.dart';
import 'package:go_habit/feature/profile/widget/about_app_dialog.dart';
import 'package:go_habit/feature/profile/widget/appearance_settings.dart';
import 'package:go_router/go_router.dart';

/// Settings, information about the app and signing out, at the bottom of the
/// profile screen.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          title: l10n.profile_section_settings,
          children: [
            const ThemeModeSelector(),
            const LanguageSelector(),
            AppSettingsTile(
              icon: Icons.notifications_outlined,
              title: l10n.profile_notifications,
              onTap: () => context.push(ProfileRoutes.notificationSettings.path),
            ),
            AppSettingsTile(
              icon: Icons.widgets_outlined,
              title: l10n.widgets,
              onTap: () => context.pushNamed(ProfileRoutes.settings.name),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        AppSection(
          title: l10n.profile_section_about,
          children: [
            AppSettingsTile(
              icon: Icons.info_outline,
              title: l10n.about_app,
              onTap: () => _showAboutAppDialog(context),
            ),
            AppSettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: l10n.privacy_policy,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const PrivacyPolicyScreen()),
              ),
            ),
            AppSettingsTile(
              icon: Icons.waving_hand_outlined,
              title: l10n.profile_show_welcome,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        // Destructive and separate from the settings, so it is not tapped by accident.
        OutlinedButton.icon(
          onPressed: () => _showSignOutConfirmationDialog(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.themeOf.colorScheme.error,
            side: BorderSide(color: context.themeOf.colorScheme.error.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.logout),
          label: Text(l10n.sign_out),
        ),
      ],
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AboutAppDialog(),
    );
  }

  void _showSignOutConfirmationDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sign_out_confirmation_title),
        content: Text(context.l10n.sign_out_confirmation_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthUserUnauthenticated) {
                context.go(AuthRoutes.login.path);
              } else if (state is AuthLogoutConfirmationRequired) {
                Navigator.pop(context);
                _showUnsyncedChangesDialog(parentContext, state.pendingChanges);
              }
            },
            child: TextButton(
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutButtonPressed());
              },
              style: TextButton.styleFrom(foregroundColor: context.themeOf.colorScheme.error),
              child: Text(context.l10n.sign_out),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnsyncedChangesDialog(BuildContext context, int pendingChanges) {
    final authBloc = context.read<AuthBloc>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sign_out_confirmation_title),
        content: Text(context.l10n.sign_out_unsynced_message(pendingChanges)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              authBloc.add(AuthLogoutButtonPressed(force: true));
            },
            style: TextButton.styleFrom(foregroundColor: context.themeOf.colorScheme.error),
            child: Text(context.l10n.sign_out_anyway),
          ),
        ],
      ),
    );
  }
}
