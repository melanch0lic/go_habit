import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/resources/assets.gen.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';

/// A destination of [BottomNavBar].
@immutable
class BottomNavDestination {
  final SvgGenImage icon;
  final String label;

  /// Shows a count badge on the icon when greater than zero.
  final int badgeCount;

  const BottomNavDestination({required this.icon, required this.label, this.badgeCount = 0});
}

/// Floating navigation bar: a pill with the main [destinations] and a separate
/// round button for the [trailing] destination (the profile).
///
/// Destination indices follow the order `destinations..., trailing`. The selected
/// destination shows a tinted indicator with its label; the others show icons only.
/// Pure presentation: the caller owns the selected index and the navigation.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<BottomNavDestination> destinations;
  final BottomNavDestination? trailing;
  final ValueChanged<int> onDestinationSelected;

  const BottomNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.trailing,
    super.key,
  });

  /// Height of the bar itself, without the outer spacing.
  static const double barHeight = 64;
  static const double _bottomGap = 8;
  static const double _minBottomInset = 12;
  static const double _horizontalMargin = 16;
  static const double _maxWidth = 480;
  static const double _groupGap = 12;
  static const double _groupPadding = 8;
  static const double _minItemWidth = 48;
  static const double _trailingMaxWidth = 168;

  static const Duration _duration = Duration(milliseconds: 250);
  static const Curve _curve = Curves.easeOutCubic;

  /// Vertical space the bar covers at the bottom of the screen, including the
  /// system inset. Scrollable content should keep this much space free.
  static double obscuredHeight(BuildContext context) {
    final systemInset = MediaQuery.paddingOf(context).bottom;
    return barHeight + _bottomGap + (systemInset > _minBottomInset ? systemInset : _minBottomInset);
  }

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : _duration;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: _minBottomInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_horizontalMargin, 0, _horizontalMargin, _bottomGap),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            // Labels may grow with the system text size, but the bar keeps its height.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: SizedBox(
                height: barHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The trailing button gets what the main group can spare, up to a
                    // comfortable width for its label.
                    final selectedInMain = currentIndex < destinations.length;
                    // A selected slot needs at least two shares; every share must fit an icon.
                    final mainShares = destinations.length + (selectedInMain ? 1 : 0);
                    final mainMinWidth = mainShares * _minItemWidth + 2 * _groupPadding;
                    final trailingMaxWidth = (constraints.maxWidth - mainMinWidth - _groupGap)
                        .clamp(_minItemWidth + 2 * _groupPadding, _trailingMaxWidth);
                    // The selected slot grows up to a triple share, as long as every other
                    // slot keeps at least a full touch target.
                    final trailingWidth =
                        currentIndex == destinations.length ? trailingMaxWidth : _minItemWidth + 2 * _groupPadding;
                    final mainInnerWidth = constraints.maxWidth - trailingWidth - _groupGap - 2 * _groupPadding;
                    // 1 px of headroom absorbs rounding of the animated flex factors.
                    const slotWidth = _minItemWidth + 1;
                    final selectedFlex =
                        ((mainInnerWidth - (destinations.length - 1) * slotWidth) / slotWidth).clamp(1.0, 3.0);
                    return Row(
                      children: [
                        Expanded(
                          child: _BarSurface(
                            child: Row(
                              children: [
                                for (final (index, destination) in destinations.indexed)
                                  _AnimatedSlot(
                                    flex: index == currentIndex ? selectedFlex : 1,
                                    duration: duration,
                                    child: _NavItem(
                                      destination: destination,
                                      selected: index == currentIndex,
                                      fillWidth: true,
                                      duration: duration,
                                      onTap: () => onDestinationSelected(index),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: _groupGap),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: trailingMaxWidth),
                            child: _BarSurface(
                              child: _NavItem(
                                destination: trailing,
                                selected: currentIndex == destinations.length,
                                fillWidth: false,
                                duration: duration,
                                onTap: () => onDestinationSelected(destinations.length),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's dark [ThemeData] does not set `brightness`, so it reports
/// [Brightness.light]; the bar's own surface color tells the themes apart.
bool _isDarkSurface(ThemeData theme) => theme.cardColor.computeLuminance() < 0.5;

/// An [Expanded] whose flex factor animates, so slots resize smoothly and always
/// add up to exactly the available width.
class _AnimatedSlot extends StatelessWidget {
  final double flex;
  final Duration duration;
  final Widget child;

  const _AnimatedSlot({required this.flex, required this.duration, required this.child});

  /// Flex factors are integers; scaling keeps the animation smooth.
  static const _precision = 1000;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: flex),
        duration: duration,
        curve: BottomNavBar._curve,
        builder: (context, value, child) => Expanded(flex: (value * _precision).round(), child: child!),
        child: child,
      );
}

/// Rounded background of a bar group, separated from page content by a soft
/// shadow and a hairline border.
class _BarSurface extends StatelessWidget {
  final Widget child;

  const _BarSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.themeOf;
    final isDark = _isDarkSurface(theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(BottomNavBar.barHeight / 2)),
        border: Border.all(color: theme.dividerColor.withValues(alpha: isDark ? 0.6 : 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(BottomNavBar._groupPadding),
        child: child,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final BottomNavDestination destination;
  final bool selected;

  /// Fill the width given by the parent slot instead of sizing to the content.
  final bool fillWidth;
  final Duration duration;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.fillWidth,
    required this.duration,
    required this.onTap,
  });

  static const _shape = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    final theme = context.themeOf;
    final colors = context.theme.commonColors;
    final isDark = _isDarkSurface(theme);

    final accent = colors.green100;
    // Inactive icons need at least 3:1 contrast against the bar.
    final inactive = isDark ? colors.darkSecondaryText : colors.lightSecondaryText;
    // Text stays in the primary text color: green on white is too low-contrast for text.
    final labelColor = isDark ? colors.darkPrimaryText : colors.lightPrimaryText;

    Widget icon = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: selected ? accent : inactive),
      duration: duration,
      curve: BottomNavBar._curve,
      builder: (context, color, _) => destination.icon.svg(
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    );
    if (destination.badgeCount > 0) {
      icon = Badge.count(count: destination.badgeCount, child: icon);
    }

    Widget content = Row(
      mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        // Only the icon is rigid: the gap and the label shrink first, so a slot that
        // is still growing (or very narrow) never overflows.
        if (selected)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: duration,
                curve: BottomNavBar._curve,
                builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.textTheme.labelLarge?.copyWith(color: labelColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
    // A button that sizes to its content animates its width; AnimatedSize does not
    // support a zero duration, so with reduced motion the size simply changes.
    if (!fillWidth && duration > Duration.zero) {
      content = AnimatedSize(duration: duration, curve: BottomNavBar._curve, child: content);
    }

    void handleTap() {
      if (!selected) AppHaptics.selection();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      // The InkWell's own semantics are excluded, so the action is exposed here.
      onTap: handleTap,
      label: destination.badgeCount > 0 ? '${destination.label}, ${destination.badgeCount}' : destination.label,
      excludeSemantics: true,
      child: Tooltip(
        message: destination.label,
        excludeFromSemantics: true,
        child: PressableScale(
          pressedScale: 0.94,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: handleTap,
              customBorder: _shape,
              child: AnimatedContainer(
                duration: duration,
                curve: BottomNavBar._curve,
                constraints: const BoxConstraints(
                  minWidth: BottomNavBar._minItemWidth,
                  minHeight: BottomNavBar._minItemWidth,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: ShapeDecoration(
                  shape: _shape,
                  color: accent.withValues(alpha: selected ? (isDark ? 0.2 : 0.14) : 0),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
