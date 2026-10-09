import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/auth_text_field.dart';

class ConfirmPasswordFormField extends StatelessWidget {
  const ConfirmPasswordFormField({
    required TextEditingController controller,
    required TextEditingController passwordController,
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    super.key,
  })  : _controller = controller,
        _passwordController = passwordController;

  final TextEditingController _controller;
  final TextEditingController _passwordController;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthTextField(
      controller: _controller,
      focusNode: focusNode,
      label: l10n.confirm_password_label,
      prefixIcon: Icons.lock_outline,
      isPassword: true,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      validator: (value) => AuthValidators.confirmPassword(value, _passwordController.text, l10n),
    );
  }
}
