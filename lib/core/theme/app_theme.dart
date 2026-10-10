import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'animation_durations.dart';
part 'app_bar_theme.dart';
part 'app_theme_extension.dart';
part 'common_colors.dart';
part 'common_text_styles.dart';
part 'design_tokens.dart';
part 'typography.dart';

const _commonColors = CommonColors();
const _typography = _Typography();
final _commonTextStyles = CommonTextStyles();
final _appBarThemes = _AppBarThemes();
const _durations = AnimationDurations();

/// Brand palette as Material color schemes. Widgets read these through
/// `Theme.of(context).colorScheme` so every component follows the active theme.
final _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _commonColors.green100,
  onPrimary: _commonColors.white,
  primaryContainer: _commonColors.green10,
  onPrimaryContainer: const Color(0xFF0B4F2E),
  secondary: _commonColors.green100,
  onSecondary: _commonColors.white,
  secondaryContainer: _commonColors.green10,
  onSecondaryContainer: const Color(0xFF0B4F2E),
  error: const Color(0xFFC62828),
  onError: _commonColors.white,
  errorContainer: const Color(0xFFFDECEC),
  onErrorContainer: const Color(0xFF7F1D1D),
  surface: _commonColors.lightCard,
  onSurface: _commonColors.lightPrimaryText,
  onSurfaceVariant: _commonColors.lightSecondaryText,
  surfaceContainerLowest: _commonColors.white,
  surfaceContainerLow: _commonColors.lightBackground,
  surfaceContainer: _commonColors.lightElevated,
  surfaceContainerHigh: _commonColors.neutralgrey10,
  surfaceContainerHighest: const Color(0xFFDDDDDD),
  outline: const Color(0xFFBDBDBD),
  outlineVariant: _commonColors.lightDivider,
  inverseSurface: _commonColors.darkGrey100,
  onInverseSurface: _commonColors.darkPrimaryText,
  inversePrimary: const Color(0xFF7FDCAE),
  shadow: _commonColors.black,
  scrim: _commonColors.black,
);

final _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: _commonColors.green100,
  onPrimary: _commonColors.white,
  primaryContainer: const Color(0xFF14492F),
  onPrimaryContainer: const Color(0xFFB6EFD2),
  secondary: _commonColors.green100,
  onSecondary: _commonColors.white,
  secondaryContainer: const Color(0xFF14492F),
  onSecondaryContainer: const Color(0xFFB6EFD2),
  error: const Color(0xFFF28B82),
  onError: const Color(0xFF3B0A08),
  errorContainer: const Color(0xFF5C1A16),
  onErrorContainer: const Color(0xFFFFDAD6),
  surface: _commonColors.darkCard,
  onSurface: _commonColors.darkPrimaryText,
  onSurfaceVariant: _commonColors.darkSecondaryText,
  surfaceContainerLowest: _commonColors.darkBackground,
  surfaceContainerLow: _commonColors.darkSurface,
  surfaceContainer: _commonColors.darkElevated,
  surfaceContainerHigh: _commonColors.darkSurfaceVariant,
  surfaceContainerHighest: const Color(0xFF3A3A3A),
  outline: const Color(0xFF6E6E6E),
  outlineVariant: _commonColors.darkDivider,
  inverseSurface: _commonColors.darkPrimaryText,
  onInverseSurface: _commonColors.darkGrey100,
  inversePrimary: const Color(0xFF0E7A47),
  shadow: _commonColors.black,
  scrim: _commonColors.black,
);

/// Component themes shared by both brightnesses; colors come from [scheme], so a
/// component looks right in light and dark without per-widget overrides.
ThemeData _buildTheme({
  required ColorScheme scheme,
  required Color background,
  required Color divider,
  required AppBarTheme appBarTheme,
  required AppThemeExtension extension,
  required TextTheme textTheme,
}) {
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.field),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  final dialogShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog));
  final disabled = scheme.onSurface.withValues(alpha: 0.38);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
    primaryColor: scheme.primary,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    cardColor: scheme.surface,
    dividerColor: divider,
    disabledColor: disabled,
    textTheme: textTheme,
    appBarTheme: appBarTheme,
    extensions: [extension],
    iconTheme: IconThemeData(color: scheme.onSurface, size: AppSizes.icon),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      minVerticalPadding: AppSpacing.md,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: dialogShape,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: background,
      modalBackgroundColor: background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
      textStyle: textTheme.bodyLarge,
    ),
    // Placement stays the default: screens position snackbars around the floating
    // navigation bar themselves.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary),
      helperStyle: textTheme.bodySmall,
      errorStyle: TextStyle(color: scheme.error),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 2)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.3),
      selectionHandleColor: scheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: disabled,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
        minimumSize: const Size.fromHeight(AppSizes.button),
        textStyle: _commonTextStyles.label,
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.button),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.button),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: _commonTextStyles.body,
        foregroundColor: scheme.primary,
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary,
      disabledColor: scheme.onSurface.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
      checkmarkColor: scheme.onPrimary,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.transparent : scheme.outline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? scheme.primary : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      side: BorderSide(color: scheme.outline, width: 2),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outline,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: 0.15),
      circularTrackColor: Colors.transparent,
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: scheme.primary,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      dividerColor: divider,
    ),
    badgeTheme: BadgeThemeData(backgroundColor: scheme.error, textColor: scheme.onError),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: scheme.onInverseSurface),
    ),
  );
}

TextTheme _textTheme({required Color primary, required Color secondary}) => TextTheme(
      displayLarge: TextStyle(color: primary),
      displayMedium: TextStyle(color: primary),
      displaySmall: TextStyle(color: primary),
      headlineLarge: TextStyle(color: primary),
      headlineMedium: TextStyle(color: primary),
      headlineSmall: TextStyle(color: primary),
      titleLarge: TextStyle(color: primary),
      titleMedium: TextStyle(color: primary),
      titleSmall: TextStyle(color: primary),
      bodyLarge: TextStyle(color: primary),
      bodyMedium: TextStyle(color: primary),
      bodySmall: TextStyle(color: secondary),
      labelLarge: TextStyle(color: primary),
      labelMedium: TextStyle(color: primary),
      labelSmall: TextStyle(color: secondary),
    );

final _lightThemeData = _buildTheme(
  scheme: _lightScheme,
  background: _commonColors.lightBackground,
  divider: _commonColors.lightDivider,
  appBarTheme: _appBarThemes.light,
  extension: AppThemeExtension.lightThemeExtension(),
  textTheme: _textTheme(primary: _commonColors.lightPrimaryText, secondary: _commonColors.lightSecondaryText),
);

final _darkThemeData = _buildTheme(
  scheme: _darkScheme,
  background: _commonColors.darkBackground,
  divider: _commonColors.darkDivider,
  appBarTheme: _appBarThemes.dark,
  extension: AppThemeExtension.darkThemeExtension(),
  textTheme: _textTheme(primary: _commonColors.darkPrimaryText, secondary: _commonColors.darkSecondaryText),
);

/// {@template app_theme}
/// An immutable class that holds properties needed
/// to build a [ThemeData] for the app.
/// {@endtemplate}
@immutable
final class AppTheme with Diagnosticable {
  /// {@macro app_theme}
  AppTheme({required this.themeMode, required this.seed})
      : darkTheme = _darkThemeData,
        lightTheme = _lightThemeData;

  /// The type of theme to use.
  final ThemeMode themeMode;

  /// The seed color to generate the [ColorScheme] from.
  final Color seed;

  /// The dark [ThemeData] for this [AppTheme].
  final ThemeData darkTheme;

  /// The light [ThemeData] for this [AppTheme].
  final ThemeData lightTheme;

  /// The default [AppTheme].
  static final defaultTheme = AppTheme(
    themeMode: ThemeMode.system,
    seed: Colors.blue,
  );

  static AppThemeExtension themeExtension(BuildContext context) => Theme.of(context).extension<AppThemeExtension>()!;

  /// The [ThemeData] for this [AppTheme].
  /// This is computed based on the [themeMode].
  ThemeData computeTheme() {
    switch (themeMode) {
      case ThemeMode.light:
        return lightTheme;
      case ThemeMode.dark:
        return darkTheme;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness == Brightness.dark ? darkTheme : lightTheme;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('seed', seed));
    properties.add(EnumProperty<ThemeMode>('type', themeMode));
    properties.add(DiagnosticsProperty<ThemeData>('lightTheme', lightTheme));
    properties.add(DiagnosticsProperty<ThemeData>('darkTheme', darkTheme));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppTheme && seed == other.seed && themeMode == other.themeMode;

  @override
  int get hashCode => Object.hash(seed, themeMode);
}
