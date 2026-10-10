import 'package:flutter/material.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';

/// The app's single-choice chip (filters, categories, schedule types). Unselected
/// chips use the theme's surface; the selected one is filled with [color] (the brand
/// color by default) and shows a check mark, so the state never relies on color alone.
class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  /// Fill of the selected chip, e.g. a category color.
  final Color? color;

  /// Shown before the label while not selected (the check mark replaces it).
  final IconData? icon;

  const AppChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.primary;
    // Category colors are mid-tone; white text keeps enough contrast on them.
    final foreground = selected ? Colors.white : scheme.onSurface;
    final leading = selected ? Icons.check : icon;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: leading == null ? null : Icon(leading, size: 18, color: foreground),
      selectedColor: fill,
      backgroundColor: scheme.surfaceContainerHigh,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (_) {
        if (!selected) AppHaptics.selection();
        onSelected();
      },
    );
  }
}
