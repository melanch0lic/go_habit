import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/auth/view/auth_validators.dart';
import 'package:go_habit/feature/auth/view/components/auth_text_field.dart';

/// Password field with a visibility toggle.
///
/// [isNewPassword] applies the password rules and tells password managers to suggest a
/// new password; otherwise only a value is required.
class PasswordFormField extends StatelessWidget {
  const PasswordFormField({
    required TextEditingController controller,
    this.isNewPassword = false,
    this.label,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    super.key,
  }) : _controller = controller;

  final TextEditingController _controller;
  final bool isNewPassword;
  final String? label;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthTextField(
      controller: _controller,
      focusNode: focusNode,
      label: label ?? l10n.password_label,
      prefixIcon: Icons.lock_outline,
      isPassword: true,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      autofillHints: [if (isNewPassword) AutofillHints.newPassword else AutofillHints.password],
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      validator: (value) =>
          isNewPassword ? AuthValidators.newPassword(value, l10n) : AuthValidators.existingPassword(value, l10n),
    );
  }
}
