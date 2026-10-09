import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/feature/auth/view/components/auth_palette.dart';

/// Text field of the auth forms. Validation runs through the enclosing [Form].
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;

  /// Hides the text and shows a visibility toggle.
  final bool isPassword;

  const AuthTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
    this.isPassword = false,
    super.key,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      obscureText: widget.isPassword && _obscured,
      autocorrect: false,
      enableSuggestions: !widget.isPassword,
      style: theme.textTheme.bodyLarge?.copyWith(color: palette.primaryText),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: palette.secondaryText),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? palette.error
                : states.contains(WidgetState.focused)
                    ? palette.accent
                    : palette.secondaryText,
          ),
        ),
        hintStyle: TextStyle(color: palette.secondaryText.withValues(alpha: 0.7)),
        errorStyle: TextStyle(color: palette.error),
        errorMaxLines: 3,
        prefixIcon: Icon(widget.prefixIcon, color: palette.secondaryText),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscured ? l10n.password_show : l10n.password_hide,
                icon: Icon(
                  _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: palette.secondaryText,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
        border: border(palette.border),
        enabledBorder: border(palette.border),
        disabledBorder: border(palette.border.withValues(alpha: 0.5)),
        focusedBorder: border(palette.accent, 1.5),
        errorBorder: border(palette.error),
        focusedErrorBorder: border(palette.error, 1.5),
      ),
    );
  }
}
