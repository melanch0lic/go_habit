part of 'app_theme.dart';

/// Spacing scale (4-point grid). Screens use [page] as the side margin and
/// [section] between sections; components use the smaller steps inside.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal margin of page content.
  static const double page = lg;

  /// Vertical gap between sections of a page.
  static const double section = xl;
}

/// Corner radii. Cards and sections use [card], inputs and small surfaces [field],
/// dialogs [dialog], bottom sheets [sheet] (top corners), chips and pills [pill].
abstract final class AppRadius {
  static const double field = 12;
  static const double card = 16;
  static const double dialog = 20;
  static const double sheet = 24;
  static const double pill = 20;
}

/// Minimum sizes of interactive elements.
abstract final class AppSizes {
  /// Minimum touch target (Material and the platform guidelines).
  static const double touchTarget = 48;

  /// Height of primary buttons.
  static const double button = 48;
  static const double iconSm = 16;
  static const double icon = 24;
}
