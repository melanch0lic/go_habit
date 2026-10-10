import 'package:flutter/material.dart';
import 'package:go_habit/core/theme/app_theme.dart';

/// A titled group of related rows on a card, e.g. a settings group. Rows are
/// separated by inset dividers; the title is a semantic header.
class AppSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const AppSection({required this.children, this.title, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const Divider(indent: AppSpacing.lg + AppSettingsTile.leadingSize + AppSpacing.md),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A row of an [AppSection]: a tinted icon, a title with an optional subtitle and
/// a trailing widget (a chevron when it opens something). [destructive] rows use
/// the theme's error color.
class AppSettingsTile extends StatelessWidget {
  static const double leadingSize = 36;

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Badge on the icon, e.g. the number of friend requests.
  final int? badgeCount;

  const AppSettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.badgeCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = destructive ? scheme.error : scheme.primary;
    final subtitle = this.subtitle;
    final badgeCount = this.badgeCount ?? 0;

    return ListTile(
      onTap: onTap,
      minTileHeight: 56,
      leading: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text('$badgeCount'),
        child: Container(
          width: leadingSize,
          height: leadingSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
      ),
      title: Text(title, style: TextStyle(color: destructive ? scheme.error : scheme.onSurface)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? (onTap == null ? null : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
    );
  }
}
