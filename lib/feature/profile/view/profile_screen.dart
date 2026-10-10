import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart' as app_auth;
import 'package:go_habit/feature/profile/domain/bloc/profile_bloc.dart';
import 'package:go_habit/feature/profile/widget/settings_section.dart';
import 'package:go_habit/feature/social/view/my_profile_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(
        authBloc: context.read<app_auth.AuthBloc>(),
      )..add(LoadProfile()),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.profile_title)),
          body: ListView(
            // The bottom inset includes the floating navigation bar.
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              MyProfileSection(email: state is ProfileLoaded ? state.email : null),
              const SizedBox(height: AppSpacing.section),
              const SettingsSection(),
            ],
          ),
        ),
      ),
    );
  }
}
