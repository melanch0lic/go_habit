import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/app_section.dart';
import 'package:go_habit/feature/language/domain/bloc/language_bloc.dart';
import 'package:go_habit/feature/theme/theme_cubit.dart';

/// Theme: follow the system, light or dark. Stored by [ThemeCubit]; the whole app
/// switches at once.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mode = context.select<ThemeCubit, ThemeMode>((cubit) => cubit.state.themeMode);
    return _ChoiceRow(
      icon: Icons.palette_outlined,
      title: l10n.theme_settings,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: ThemeMode.system, label: _SegmentLabel(l10n.theme_system)),
          ButtonSegment(value: ThemeMode.light, label: _SegmentLabel(l10n.theme_light)),
          ButtonSegment(value: ThemeMode.dark, label: _SegmentLabel(l10n.theme_dark)),
        ],
        selected: {mode},
        onSelectionChanged: (selection) {
          AppHaptics.selection();
          context.read<ThemeCubit>().setThemeMode(selection.single);
        },
      ),
    );
  }
}

/// App language. Stored by [LanguageBloc].
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.select<LanguageBloc, String>((bloc) => bloc.state.currentLocale);
    return _ChoiceRow(
      icon: Icons.language,
      title: l10n.language_label,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          // Language names are shown in their own language.
          ButtonSegment(value: 'ru', label: _SegmentLabel('Русский')),
          ButtonSegment(value: 'en', label: _SegmentLabel('English')),
        ],
        // Any locale other than Russian is shown in English.
        selected: {if (locale == 'ru') 'ru' else 'en'},
        onSelectionChanged: (selection) {
          AppHaptics.selection();
          context.read<LanguageBloc>().add(ChangeLanguage(selection.single));
        },
      ),
    );
  }
}

/// An icon and title like [AppSettingsTile], with a full-width control below, so
/// long labels and large text never squeeze the control.
class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _ChoiceRow({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: AppSettingsTile.leadingSize,
                height: AppSettingsTile.leadingSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// One line, shrunk rather than broken mid-word on narrow screens or with large text.
class _SegmentLabel extends StatelessWidget {
  final String text;

  const _SegmentLabel(this.text);

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
}
