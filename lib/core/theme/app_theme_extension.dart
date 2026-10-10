part of 'app_theme.dart';

/// App-specific design tokens on top of the Material theme. [commonColors] and
/// [commonTextStyles] are brand constants; the colors below depend on the theme.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final CommonColors commonColors;
  final CommonTextStyles commonTextStyles;
  final AnimationDurations durations;

  /// The dark "feature" surface of habit and community cards, in both themes.
  final Color featureSurface;

  /// Text and icons on [featureSurface].
  final Color onFeatureSurface;
  final Color onFeatureSurfaceMuted;

  /// Positive state (done, available, success). Data colors keep their meaning in
  /// both themes; only their contrast is tuned.
  final Color success;

  /// Attention without error (offline banners, pending sync).
  final Color warningContainer;

  const AppThemeExtension({
    required this.commonColors,
    required this.commonTextStyles,
    required this.durations,
    required this.featureSurface,
    required this.onFeatureSurface,
    required this.onFeatureSurfaceMuted,
    required this.success,
    required this.warningContainer,
  });

  factory AppThemeExtension.lightThemeExtension() => AppThemeExtension(
        commonColors: _commonColors,
        commonTextStyles: _commonTextStyles,
        durations: _durations,
        featureSurface: _commonColors.darkCard,
        onFeatureSurface: _commonColors.white,
        onFeatureSurfaceMuted: _commonColors.white.withValues(alpha: 0.8),
        success: _commonColors.green100,
        warningContainer: const Color(0xFFFFF4D6),
      );

  factory AppThemeExtension.darkThemeExtension() => AppThemeExtension(
        commonColors: _commonColors,
        commonTextStyles: _commonTextStyles,
        durations: _durations,
        // Lighter than the dark cards, so feature cards stand out instead of sinking.
        featureSurface: _commonColors.darkSurfaceVariant,
        onFeatureSurface: _commonColors.white,
        onFeatureSurfaceMuted: _commonColors.white.withValues(alpha: 0.8),
        success: _commonColors.green100,
        warningContainer: const Color(0xFF4A3B12),
      );

  @override
  AppThemeExtension copyWith({
    CommonColors? commonColors,
    CommonTextStyles? commonTextStyles,
    AnimationDurations? durations,
    Color? featureSurface,
    Color? onFeatureSurface,
    Color? onFeatureSurfaceMuted,
    Color? success,
    Color? warningContainer,
  }) =>
      AppThemeExtension(
        commonColors: commonColors ?? this.commonColors,
        commonTextStyles: commonTextStyles ?? this.commonTextStyles,
        durations: durations ?? this.durations,
        featureSurface: featureSurface ?? this.featureSurface,
        onFeatureSurface: onFeatureSurface ?? this.onFeatureSurface,
        onFeatureSurfaceMuted: onFeatureSurfaceMuted ?? this.onFeatureSurfaceMuted,
        success: success ?? this.success,
        warningContainer: warningContainer ?? this.warningContainer,
      );

  @override
  AppThemeExtension lerp(covariant ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      commonColors: commonColors,
      commonTextStyles: commonTextStyles,
      durations: durations,
      featureSurface: Color.lerp(featureSurface, other.featureSurface, t)!,
      onFeatureSurface: Color.lerp(onFeatureSurface, other.onFeatureSurface, t)!,
      onFeatureSurfaceMuted: Color.lerp(onFeatureSurfaceMuted, other.onFeatureSurfaceMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
    );
  }
}
