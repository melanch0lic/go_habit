part of 'app_theme.dart';

/// WCAG contrast ratio of two opaque colors (1–21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

extension ReadableColor on Color {
  /// This color, darkened on light backgrounds or lightened on dark ones just
  /// enough to reach [ratio] against [background] (4.5:1 is WCAG AA for text). Data
  /// colors such as category colors keep their hue and stay recognizable.
  Color readableOn(Color background, {double ratio = 4.5}) {
    if (contrastRatio(this, background) >= ratio) return this;
    final target = background.computeLuminance() > 0.4 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    for (var t = 0.05; t < 1; t += 0.05) {
      final candidate = Color.lerp(this, target, t)!;
      if (contrastRatio(candidate, background) >= ratio) return candidate;
    }
    return target;
  }
}
