import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/router/routes_enum.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_bloc.dart';
import 'package:go_habit/feature/auth/domain/bloc/auth_form_bloc.dart';
import 'package:go_habit/feature/auth/domain/models/auth_failure.dart';
import 'package:go_habit/feature/auth/domain/repositories/i_authentication_repository.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/components.dart';
import 'package:go_router/go_router.dart';

/// Sign-in screen. After a successful sign-in the router opens the app as soon as the
/// new session arrives, so this screen does not navigate by itself.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthFormBloc(context.read<IAuthenticationRepository>()),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatefulWidget {
  const _SignInView();

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  var _autovalidateMode = AutovalidateMode.disabled;

  /// A failed email link (expired confirmation or reset link) reported by [AuthBloc].
  AuthFailure? _linkFailure;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthBloc>().state case AuthUserUnauthenticated(:final failure?)) {
      _linkFailure = failure;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.isSubmitting) return;
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
      _linkFailure = null;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    formBloc.add(AuthFormSignInSubmitted(
      email: AuthValidators.normalizeEmail(_emailController.text),
      password: _passwordController.text,
    ));
  }

  void _onEdited(String _) {
    final formBloc = context.read<AuthFormBloc>();
    if (formBloc.state.failure != null) formBloc.add(const AuthFormFailureDismissed());
    if (_linkFailure != null) setState(() => _linkFailure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = AuthPalette.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state case AuthUserUnauthenticated(:final failure?)) setState(() => _linkFailure = failure);
      },
      child: BlocBuilder<AuthFormBloc, AuthFormState>(
        builder: (context, state) {
          final submitting = state.isSubmitting;
          return AuthLayout(
            title: l10n.welcome_back,
            subtitle: l10n.auth_sign_in_subtitle,
            child: AutofillGroup(
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
                      enabled: !submitting,
                      onChanged: _onEdited,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: submitting
                            ? null
                            : () => context.push(AuthRoutes.forgotPassword.path, extra: _emailController.text.trim()),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.accent,
                          minimumSize: const Size(48, 48),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: Text(l10n.auth_forgot_password),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AuthErrorBanner(failure: state.failure ?? _linkFailure),
                    AuthSubmitButton(label: l10n.sign_in, loading: submitting, onPressed: _submit),
                    const SizedBox(height: 24),
                    AuthNavigationButton(
                      text: l10n.auth_no_account,
                      action: l10n.auth_create_account_action,
                      onPressed: submitting ? null : () => context.push(AuthRoutes.register.path),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
