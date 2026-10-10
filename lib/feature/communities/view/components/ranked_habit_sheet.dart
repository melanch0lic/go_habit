import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/feature/communities/view/community_texts.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/habit_schedule_section.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';

/// What the user chose in [RankedHabitSheet].
sealed class RankedHabitChoice {
  const RankedHabitChoice();
}

/// Create a habit from the template with these parameters and rank with it.
final class CreateRankedHabit extends RankedHabitChoice {
  final String title;
  final String description;

  /// The user's own schedule, prefilled from the template's recommendation.
  final HabitSchedule schedule;

  const CreateRankedHabit({required this.title, required this.description, required this.schedule});
}

/// Join without taking part in the ranking.
final class JoinWithoutRanking extends RankedHabitChoice {
  const JoinWithoutRanking();
}

/// Creating the ranked habit from a template, with the user's own name, target and
/// schedule (prefilled from the template's recommendation). When [joining], the user
/// may instead join without the ranking.
class RankedHabitSheet extends StatefulWidget {
  final HabitTemplate template;

  /// The user's habits, to point out a similar one before another is created.
  final List<Habit> habits;
  final bool joining;

  const RankedHabitSheet({required this.template, required this.habits, required this.joining, super.key});

  static Future<RankedHabitChoice?> show(
    BuildContext context, {
    required HabitTemplate template,
    required List<Habit> habits,
    required bool joining,
  }) =>
      showModalBottomSheet<RankedHabitChoice>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: context.themeOf.scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => RankedHabitSheet(template: template, habits: habits, joining: joining),
      );

  /// Whether [habit] looks like the template (same name in any language, or icon).
  static bool isSimilar(Habit habit, HabitTemplate template) {
    final title = habit.title.trim().toLowerCase();
    if (title.isEmpty) return false;
    return habit.icon == template.icon ||
        template.title.values.map((t) => t.toLowerCase()).any((t) => title.contains(t) || t.contains(title));
  }

  @override
  State<RankedHabitSheet> createState() => _RankedHabitSheetState();
}

class _RankedHabitSheetState extends State<RankedHabitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  late final _target = TextEditingController(text: widget.template.targetValue?.toString() ?? '');
  bool _ranked = true;
  late ScheduleType _scheduleType = widget.template.recommendedSchedule.type;
  late int _weeklyTarget = widget.template.recommendedSchedule.weeklyTarget ?? 3;
  late Set<int> _weekdays = {...widget.template.recommendedSchedule.weekdays};
  bool _showWeekdaysError = false;

  /// Null while weekdays are chosen but none is ticked.
  HabitSchedule? get _schedule => switch (_scheduleType) {
        ScheduleType.daily => HabitSchedule.daily,
        ScheduleType.weeklyTarget => HabitSchedule.weeklyTarget(_weeklyTarget),
        ScheduleType.weekdays => _weekdays.isEmpty ? null : HabitSchedule.weekdays(_weekdays),
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_title.text.isEmpty) _title.text = widget.template.titleFor(languageCodeOf(context));
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_ranked) {
      Navigator.pop<RankedHabitChoice>(context, const JoinWithoutRanking());
      return;
    }
    final schedule = _schedule;
    setState(() => _showWeekdaysError = schedule == null);
    if (!_formKey.currentState!.validate() || schedule == null) return;
    final l10n = context.l10n;
    final description = widget.template.descriptionFor(languageCodeOf(context));
    final target = widget.template.targetText(l10n, value: int.tryParse(_target.text));
    Navigator.pop<RankedHabitChoice>(
      context,
      CreateRankedHabit(
        title: _title.text.trim(),
        description: target == null ? description : l10n.create_habit_description(description, target),
        schedule: schedule,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final template = widget.template;
    final similar = widget.habits.where((habit) => RankedHabitSheet.isSimilar(habit, template)).firstOrNull;
    final unit = template.targetText(l10n, value: int.tryParse(_target.text) ?? template.targetValue);

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (similar != null) ...[
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.create_habit_similar(similar.title), style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _title,
          textInputAction: template.hasTarget ? TextInputAction.next : TextInputAction.done,
          decoration: InputDecoration(labelText: l10n.create_habit_name_label),
          validator: (value) => (value ?? '').trim().isEmpty ? l10n.create_habit_name_label : null,
        ),
        if (template.hasTarget) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: InputDecoration(
              labelText: l10n.create_habit_target_label,
              // "20 страниц" → "страниц": the number is in the field.
              suffixText: unit?.replaceFirst(RegExp(r'^\d+\s*'), ''),
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) => (int.tryParse(value ?? '') ?? 0) > 0 ? null : l10n.create_habit_target_label,
          ),
        ],
        const SizedBox(height: 16),
        HabitScheduleSection(
          type: _scheduleType,
          weeklyTarget: _weeklyTarget,
          weekdays: _weekdays,
          showWeekdaysError: _showWeekdaysError,
          summary: _schedule == null ? null : l10n.scheduleSummary(_schedule!),
          onTypeChanged: (type) => setState(() => _scheduleType = type),
          onTargetChanged: (target) => setState(() => _weeklyTarget = target),
          onWeekdayToggled: (day) => setState(() {
            _weekdays = {..._weekdays};
            if (!_weekdays.remove(day)) _weekdays.add(day);
            if (_weekdays.isNotEmpty) _showWeekdaysError = false;
          }),
        ),
        const SizedBox(height: 8),
        Text(l10n.create_habit_hint, style: theme.textTheme.bodySmall),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(child: Text(template.icon, style: const TextStyle(fontSize: 28))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          widget.joining ? l10n.join_sheet_title : l10n.community_create_habit_title,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.joining)
                  RadioGroup<bool>(
                    groupValue: _ranked,
                    onChanged: (value) => setState(() => _ranked = value ?? _ranked),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RadioListTile<bool>(
                          value: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.join_option_ranked),
                          subtitle: Text(l10n.join_option_ranked_hint),
                        ),
                        if (_ranked) Padding(padding: const EdgeInsets.only(bottom: 8), child: fields),
                        RadioListTile<bool>(
                          value: false,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.join_option_unranked),
                          subtitle: Text(l10n.join_option_unranked_hint),
                        ),
                      ],
                    ),
                  )
                else
                  fields,
                const SizedBox(height: 16),
                PressableScale(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(widget.joining ? l10n.community_join : l10n.community_create_habit_action),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
