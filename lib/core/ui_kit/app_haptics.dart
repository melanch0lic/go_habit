import 'package:flutter/services.dart';

/// The app's haptic vocabulary. Call these for meaningful moments only, never for
/// every tap. Devices or platforms without haptics ignore the calls.
abstract final class AppHaptics {
  /// Moving between options: navigation destinations, segmented choices, switches.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// A meaningful action has succeeded, e.g. a habit was marked as done.
  static Future<void> success() => HapticFeedback.lightImpact();
}
