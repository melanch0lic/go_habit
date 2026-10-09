import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_form_bloc.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/components.dart';
import 'package:go_router/go_router.dart';

/// Registration screen.
///
/// Without email confirmation the new session opens the app through the router. With
/// confirmation enabled the screen switches to next steps and the user stays signed out
/// until the email link is followed.
class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthFormBloc(context.read<IAuthenticationRepository>()),
      child: const _RegistrationView(),
    );
  }
}

class _RegistrationView extends StatefulWidget {
  const _RegistrationView();

  @override
  State<_RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<_RegistrationView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  var _autovalidateMode = AutovalidateMode.disabled;

  /// Set once the confirmation email was requested.
  String? _pendingEmail;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.isSubmitting) return;
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    formBloc.add(AuthFormSignUpSubmitted(
      email: AuthValidators.normalizeEmail(_emailController.text),
      password: _passwordController.text,
    ));
  }

  void _onEdited(String _) {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.failure != null) formBloc.add(const AuthFormFailureDismissed());
  }

  void _backToSignIn() => context.canPop() ? context.pop() : context.go(AuthRoutes.login.path);

  void _onStateChanged(BuildContext context, AuthFormState state) {
    switch (state.success) {
      case AuthFormSuccess.confirmationRequired:
        setState(() => _pendingEmail = AuthValidators.normalizeEmail(_emailController.text));
      case AuthFormSuccess.confirmationResent:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.auth_email_resent)));
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pendingEmail = _pendingEmail;

    return BlocConsumer<AuthFormBloc, AuthFormState>(
      listenWhen: (previous, current) => current.status == AuthFormStatus.success,
      listener: _onStateChanged,
      builder: (context, state) {
        final submitting = state.isSubmitting;
        return AuthLayout(
          title: pendingEmail == null ? l10n.create_account : l10n.auth_check_email_title,
          subtitle: pendingEmail == null ? l10n.auth_sign_up_subtitle : null,
          leading: pendingEmail == null ? null : const AuthStatusIcon(Icons.mark_email_unread_outlined),
          child: AuthFadeSwitcher(
            child: pendingEmail != null
                ? Column(
                    key: const ValueKey('pending'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthErrorBanner(failure: state.failure),
                      EmailSentPanel(
                        message: l10n.auth_confirm_email_message(pendingEmail),
                        hint: l10n.auth_check_email_hint,
                        resending: submitting,
                        onResend: () =>
                            context.read<AuthFormBloc>().add(AuthFormConfirmationResent(email: pendingEmail)),
                        onBackToSignIn: _backToSignIn,
                      ),
                    ],
                  )
                : AutofillGroup(
                    key: const ValueKey('form'),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _autovalidateMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          EmailFieldWidget(
                            emailController: _emailController,
                            enabled: !submitting,
                            onChanged: _onEdited,
                            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          PasswordFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
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
                          AuthSubmitButton(label: l10n.register, loading: submitting, onPressed: _submit),
                          const SizedBox(height: 24),
                          AuthNavigationButton(
                            text: l10n.auth_have_account,
                            action: l10n.sign_in,
                            onPressed: submitting ? null : _backToSignIn,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
