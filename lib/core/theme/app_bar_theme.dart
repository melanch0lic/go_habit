part of 'app_theme.dart';

/// Status and navigation bar style for a theme of [brightness]: transparent status
/// bar with icons that contrast with the background, navigation bar in the
/// background color.
SystemUiOverlayStyle systemBars(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? _commonColors.darkBackground : _commonColors.lightBackground;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor: background,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor: background,
  );
}

class _AppBarThemes {
  final light = AppBarTheme(
    backgroundColor: _commonColors.lightBackground,
    systemOverlayStyle: systemBars(Brightness.light),
    surfaceTintColor: _commonColors.lightBackground,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: _commonColors.lightPrimaryText,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      fontFamily: _typography.tbcxMediumFont,
    ),
    iconTheme: IconThemeData(color: _commonColors.lightPrimaryText),
    actionsIconTheme: IconThemeData(color: _commonColors.lightPrimaryText),
  );

  final dark = AppBarTheme(
    backgroundColor: _commonColors.darkBackground,
    systemOverlayStyle: systemBars(Brightness.dark),
    surfaceTintColor: _commonColors.darkBackground,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: _commonColors.darkPrimaryText,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      fontFamily: _typography.tbcxMediumFont,
    ),
    iconTheme: IconThemeData(color: _commonColors.darkPrimaryText),
    actionsIconTheme: IconThemeData(color: _commonColors.darkPrimaryText),
  );
}
