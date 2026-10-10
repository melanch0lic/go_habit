import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habits/view/components/modal_bottom_sheet.dart' show getCategoryIcon, hexToColor;

/// Name, color and icon of a category, as on the habit cards.
@immutable
class CategoryStyle {
  final String name;
  final Color color;
  final IconData icon;

  const CategoryStyle({required this.name, required this.color, required this.icon});

  factory CategoryStyle.of(BuildContext context, String categoryId) {
    final categories = switch (context.watch<HabitCategoryBloc>().state) {
      HabitCategoryLoaded(:final categories) => categories,
      HabitCategoryError(:final categories) => categories,
      _ => const <HabitCategory>[],
    };
    final category = categories.where((category) => category.id == categoryId).firstOrNull;
    return CategoryStyle(
      name: category?.name ?? categoryId,
      color: category == null ? Colors.grey : hexToColor(category.color),
      icon: getCategoryIcon(categoryId),
    );
  }
}

/// The colored category pill of the habit cards.
class CategoryPill extends StatelessWidget {
  final String categoryId;

  const CategoryPill({required this.categoryId, super.key});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(context, categoryId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      // Darkened just enough for the white label (WCAG AA); the hue stays recognizable.
      decoration: BoxDecoration(color: style.color.readableOn(Colors.white), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              style.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// The emoji in a dark circle, as on the habit cards.
class EmojiBadge extends StatelessWidget {
  final String emoji;
  final double size;

  const EmojiBadge(this.emoji, {this.size = 48, super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size + 16,
          height: size + 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.black87.withValues(alpha: 0.5), shape: BoxShape.circle),
          child: Text(emoji, style: TextStyle(fontSize: size * 0.62)),
        ),
      );
}
