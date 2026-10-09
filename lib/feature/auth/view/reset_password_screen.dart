import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_form_bloc.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:go_habit/feature/auth/view/components/components.dart';
import 'package:go_router/go_router.dart';

/// Sets a new password after the user followed a reset link.
///
/// The link signs the user in with a recovery session; the router opens this screen
/// when that happens. Leaving it keeps the user signed in with the old password.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthFormBloc(context.read<IAuthenticationRepository>()),
      child: const _ResetPasswordView(),
    );
  }
}

class _ResetPasswordView extends StatefulWidget {
  const _ResetPasswordView();

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _confirmPasswordFocus = FocusNode();
  var _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.isSubmitting) return;
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    formBloc.add(AuthFormNewPasswordSubmitted(password: _passwordController.text));
  }

  void _onEdited(String _) {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.failure != null) formBloc.add(const AuthFormFailureDismissed());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<AuthFormBloc, AuthFormState>(
      listenWhen: (previous, current) => current.success == AuthFormSuccess.passwordUpdated,
      listener: (context, state) {
        AppHaptics.success();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.auth_password_updated)));
        context.go(HomeRoutes.home.path);
      },
      builder: (context, state) {
        final submitting = state.isSubmitting;
        return AuthLayout(
          title: l10n.auth_new_password_title,
          subtitle: l10n.auth_new_password_subtitle,
          leading: const AuthStatusIcon(Icons.lock_reset),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordFormField(
                    controller: _passwordController,
                    label: l10n.auth_new_password_label,
                    isNewPassword: true,
                    enabled: !submitting,
                    textInputAction: TextInputAction.next,
                    onChanged: _onEdited,
                    onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                  ),
                  PasswordRequirements(controller: _passwordController),
                  const SizedBox(height: 16),
                  ConfirmPasswordFormField(
                    controller: _confirmPasswordController,
                    passwordController: _passwordController,
                    focusNode: _confirmPasswordFocus,
                    enabled: !submitting,
                    onChanged: _onEdited,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  AuthErrorBanner(failure: state.failure),
                  AuthSubmitButton(label: l10n.auth_new_password_save, loading: submitting, onPressed: _submit),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: submitting ? null : () => context.go(HomeRoutes.home.path),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthPalette.of(context).secondaryText,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.auth_later),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
