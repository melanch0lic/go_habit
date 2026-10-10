import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG contrast ratio of two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final light = AppTheme.defaultTheme.lightTheme;
  final dark = AppTheme.defaultTheme.darkTheme;
  final themes = {'light': light, 'dark': dark};

  test('each theme has a color scheme of its own brightness', () {
    expect((light.brightness, light.colorScheme.brightness), (Brightness.light, Brightness.light));
    expect((dark.brightness, dark.colorScheme.brightness), (Brightness.dark, Brightness.dark));
    expect(dark.colorScheme.surface.computeLuminance(), lessThan(0.05), reason: 'dark surfaces are dark');
  });

  test('the brand green is the primary color in both themes', () {
    for (final theme in themes.values) {
      expect(theme.colorScheme.primary, const Color(0xFF26B571));
      expect(theme.primaryColor, theme.colorScheme.primary);
    }
  });

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    group(name, () {
      final scheme = theme.colorScheme;
      final background = theme.scaffoldBackgroundColor;

      test('text is readable on the background and on cards (WCAG AA)', () {
        for (final surface in [background, scheme.surface]) {
          expect(contrast(theme.textTheme.bodyMedium!.color!, surface), greaterThanOrEqualTo(4.5));
          expect(contrast(theme.textTheme.bodySmall!.color!, surface), greaterThanOrEqualTo(4.5),
              reason: 'secondary text');
          expect(contrast(scheme.onSurfaceVariant, surface), greaterThanOrEqualTo(4.5));
          expect(contrast(scheme.error, surface), greaterThanOrEqualTo(4.5),
              reason: 'error text and destructive actions');
        }
        expect(contrast(scheme.onInverseSurface, scheme.inverseSurface), greaterThanOrEqualTo(4.5),
            reason: 'snackbars');
      });

      test('dialogs, sheets, menus and cards use the theme surfaces', () {
        expect(theme.dialogTheme.backgroundColor, scheme.surface);
        expect(theme.bottomSheetTheme.backgroundColor, background);
        expect(theme.popupMenuTheme.color, scheme.surface);
        expect(theme.cardTheme.color, scheme.surface);
        expect(theme.cardColor, scheme.surface);
      });

      test('controls show their states in the brand color', () {
        Color? resolve<T>(WidgetStateProperty<T?>? property, Set<WidgetState> states) =>
            property?.resolve(states) as Color?;
        expect(resolve(theme.switchTheme.trackColor, {WidgetState.selected}), scheme.primary);
        expect(resolve(theme.switchTheme.trackColor, {}), isNot(scheme.primary));
        expect(resolve(theme.checkboxTheme.fillColor, {WidgetState.selected}), scheme.primary);
        expect(resolve(theme.radioTheme.fillColor, {WidgetState.selected}), scheme.primary);
        final focused = theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, scheme.primary, reason: 'a visible focus ring');
        final error = theme.inputDecorationTheme.errorBorder! as OutlineInputBorder;
        expect(error.borderSide.color, scheme.error);
        expect(theme.textSelectionTheme.cursorColor, scheme.primary);
      });

      test('interactive elements keep the minimum touch target', () {
        final textButton = theme.textButtonTheme.style!.minimumSize!.resolve({})!;
        expect(textButton.height, greaterThanOrEqualTo(AppSizes.touchTarget));
        final iconButton = theme.iconButtonTheme.style!.minimumSize!.resolve({})!;
        expect(iconButton.shortestSide, greaterThanOrEqualTo(AppSizes.touchTarget));
      });

      test('system bar icons contrast with the background', () {
        final style = systemBars(theme.brightness);
        final expected = theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
        expect(style.statusBarIconBrightness, expected);
        expect(style.systemNavigationBarIconBrightness, expected);
        expect(style.systemNavigationBarColor, background);
        expect(theme.appBarTheme.systemOverlayStyle, isA<SystemUiOverlayStyle>());
      });

      test('text on the feature surface is readable', () {
        final tokens = theme.extension<AppThemeExtension>()!;
        expect(contrast(tokens.onFeatureSurface, tokens.featureSurface), greaterThanOrEqualTo(7));
      });
    });
  }

  test('dark feature cards stand out from dark cards instead of sinking below them', () {
    final tokens = dark.extension<AppThemeExtension>()!;
    expect(tokens.featureSurface.computeLuminance(), greaterThan(dark.colorScheme.surface.computeLuminance()));
  });

  group('ThemeCubit', () {
    test('stores the choice and restores it on the next start', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = ThemeCubit();
      await cubit.setThemeMode(ThemeMode.dark);
      expect(cubit.state.themeMode, ThemeMode.dark);
      await cubit.close();

      final restored = ThemeCubit();
      await pumpEventQueue();
      expect(restored.state.themeMode, ThemeMode.dark);
      await restored.close();
    });

    test('defaults to following the system', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = ThemeCubit();
      await pumpEventQueue();
      expect(cubit.state.themeMode, ThemeMode.system);
      await cubit.close();
    });
  });
}
