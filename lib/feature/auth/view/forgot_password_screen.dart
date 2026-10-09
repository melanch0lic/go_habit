import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_form_bloc.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/components.dart';
import 'package:go_router/go_router.dart';

/// Requests a password reset email. The confirmation never says whether an account
/// with the address exists.
class ForgotPasswordScreen extends StatelessWidget {
  /// Prefilled from the sign-in form.
  final String initialEmail;

  const ForgotPasswordScreen({this.initialEmail = '', super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthFormBloc(context.read<IAuthenticationRepository>()),
      child: _ForgotPasswordView(initialEmail: initialEmail),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordView({required this.initialEmail});

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  var _autovalidateMode = AutovalidateMode.disabled;

  /// Set once the reset email was requested.
  String? _sentTo;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.isSubmitting) return;
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    formBloc.add(AuthFormPasswordResetRequested(email: AuthValidators.normalizeEmail(_emailController.text)));
  }

  void _resend(String email) => context.read<AuthFormBloc>().add(AuthFormPasswordResetRequested(email: email));

  void _onEdited(String _) {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.failure != null) formBloc.add(const AuthFormFailureDismissed());
  }

  void _backToSignIn() => context.canPop() ? context.pop() : context.go(AuthRoutes.login.path);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sentTo = _sentTo;

    return BlocConsumer<AuthFormBloc, AuthFormState>(
      listenWhen: (previous, current) => current.success == AuthFormSuccess.resetEmailSent,
      listener: (context, state) {
        if (_sentTo != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.auth_email_resent)));
        } else {
          setState(() => _sentTo = AuthValidators.normalizeEmail(_emailController.text));
        }
      },
      builder: (context, state) {
        final submitting = state.isSubmitting;
        return AuthLayout(
          title: sentTo == null ? l10n.auth_reset_title : l10n.auth_check_email_title,
          subtitle: sentTo == null ? l10n.auth_reset_subtitle : null,
          leading: AuthStatusIcon(sentTo == null ? Icons.lock_reset : Icons.mark_email_unread_outlined),
          child: AuthFadeSwitcher(
            child: sentTo != null
                ? Column(
                    key: const ValueKey('sent'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthErrorBanner(failure: state.failure),
                      EmailSentPanel(
                        message: l10n.auth_reset_sent_message(sentTo),
                        hint: l10n.auth_reset_sent_hint,
                        resending: submitting,
                        onResend: () => _resend(sentTo),
                        onBackToSignIn: _backToSignIn,
                      ),
                    ],
                  )
                : Form(
                    // The GlobalKey also tells the switcher the two states apart.
                    key: _formKey,
                    autovalidateMode: _autovalidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EmailFieldWidget(
                          emailController: _emailController,
                          enabled: !submitting,
                          textInputAction: TextInputAction.send,
                          onChanged: _onEdited,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 24),
                        AuthErrorBanner(failure: state.failure),
                        AuthSubmitButton(label: l10n.auth_reset_send, loading: submitting, onPressed: _submit),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: submitting ? null : _backToSignIn,
                          style: TextButton.styleFrom(
                            foregroundColor: AuthPalette.of(context).accent,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(l10n.auth_back_to_sign_in),
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
