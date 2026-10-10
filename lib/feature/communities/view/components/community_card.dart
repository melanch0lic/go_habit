import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/communities/view/components/category_style.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';

/// A catalog entry in the style of the habit cards, with its recommended frequency.
class CommunityCard extends StatelessWidget {
  final HabitTemplate template;

  /// Real participant count; null hides it (unknown while offline).
  final int? memberCount;
  final bool isMember;

  /// Extra lines under the description, e.g. the user's progress in "My communities".
  final Widget? footer;
  final VoidCallback onTap;

  const CommunityCard({
    required this.template,
    required this.isMember,
    required this.onTap,
    this.memberCount,
    this.footer,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = languageCodeOf(context);
    final colors = context.theme.commonColors;
    final memberCount = this.memberCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: PressableScale(
        child: Material(
          color: context.themeOf.focusColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiBadge(template.icon, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.titleFor(language),
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          template.descriptionFor(language),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            CategoryPill(categoryId: template.categoryId),
                            // Wraps on narrow screens with large text.
                            Text.rich(
                              TextSpan(children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.event_repeat,
                                      size: 16,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                TextSpan(text: l10n.scheduleShort(template.recommendedSchedule)),
                              ]),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                            ),
                            if (memberCount != null)
                              Text(
                                memberCount > 0
                                    ? l10n.communities_members(memberCount)
                                    : l10n.communities_no_members_yet,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                              ),
                            if (isMember)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: colors.green100),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.communities_joined_badge,
                                    style: TextStyle(color: colors.green100, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (footer case final footer?) ...[const SizedBox(height: 10), footer],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const ExcludeSemantics(child: Icon(Icons.chevron_right, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
