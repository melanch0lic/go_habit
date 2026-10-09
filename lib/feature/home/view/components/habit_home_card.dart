import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_habit/feature/categories/bloc/habit_category_bloc.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habit_stats/bloc/habit_stats_bloc.dart';
import 'package:go_habit/feature/habit_stats/widget/habit_completion_button.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

enum HabitCardDisplayMode {
  linear,
  circular,
  none,
}

class HabitHomeCard extends StatefulWidget {
  final Habit habit;
  final HabitCategory category;
  final HabitCardDisplayMode displayMode;

  const HabitHomeCard({
    required this.habit,
    required this.category,
    this.displayMode = HabitCardDisplayMode.linear,
    super.key,
  });

  @override
  State<HabitHomeCard> createState() => _HabitHomeCardState();
}

class _HabitHomeCardState extends State<HabitHomeCard> {
  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  IconData _getCategoryIcon(String categoryId, HabitCategoryState state) {
    if (state is HabitCategoryError || state is HabitCategoryLoaded) {
      switch (categoryId) {
        case 'art':
          return Icons.brush;
        case 'education':
          return Icons.school;
        case 'health':
          return Icons.fitness_center;
        case 'money':
          return Icons.attach_money;
        case 'selv-development':
          return Icons.self_improvement;
        case 'sport':
          return Icons.sports_soccer;
        case 'work':
          return Icons.work;
        default:
          return Icons.category;
      }
    }
    return Icons.category;
  }

  Widget _buildProgressIndicator(Color cardColor, double progress) {
    switch (widget.displayMode) {
      case HabitCardDisplayMode.linear:
        return LinearPercentIndicator(
          lineHeight: 10,
          percent: progress,
          backgroundColor: Colors.white.withValues(alpha: .5),
          progressColor: cardColor.withValues(alpha: 0.9),
          barRadius: const Radius.circular(4),
          padding: EdgeInsets.zero,
          animation: true,
        );
      case HabitCardDisplayMode.circular:
        return const SizedBox.shrink();
      case HabitCardDisplayMode.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHabitIcon(Color cardColor, double progress) {
    if (widget.displayMode == HabitCardDisplayMode.circular) {
      return Stack(
        alignment: Alignment.center,
        children: [
          CircularPercentIndicator(
            radius: 32,
            lineWidth: 4,
            percent: progress,
            backgroundColor: Colors.white.withValues(alpha: .5),
            progressColor: cardColor.withValues(alpha: 0.9),
            animation: true,
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Text(
                  widget.habit.icon ?? '🎯',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Text(
            widget.habit.icon ?? '🎯',
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _getColorFromHex(widget.category.color);
    final completedToday = context.select<HabitStatsBloc, bool>(
      (bloc) => switch (bloc.state) {
        final HabitStatsLoaded loaded => loaded.isCompletedToday(widget.habit.id),
        _ => false,
      },
    );
    final progress = completedToday ? 1.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: BlocBuilder<HabitCategoryBloc, HabitCategoryState>(
                builder: (context, state) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(widget.category.id, state),
                        color: cardColor,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.category.name,
                        style: TextStyle(
                          color: cardColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildHabitIcon(cardColor, progress),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.habit.title,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600, color: cardColor.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.habit.description ?? '',
                        style: TextStyle(fontSize: 14, color: cardColor.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 8),
                      _buildProgressIndicator(cardColor, progress),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 40),
                  child: HabitCompletionButton(
                    habitId: widget.habit.id,
                    color: cardColor.withValues(alpha: 0.9),
                    iconColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
