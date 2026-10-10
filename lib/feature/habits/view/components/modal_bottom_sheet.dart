import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';

/// What the form produced; the caller turns it into AddHabit or UpdateHabit.
/// `resetStreak` is true only when the user confirmed a change of schedule type.
typedef HabitDraft = ({
  String title,
  String description,
  String icon,
  String categoryId,
  HabitSchedule schedule,
  bool resetStreak,
});

/// Form for a new habit, or for editing [habit]. Pops with a [HabitDraft] on save and
/// with nothing on cancel; unsaved changes are never dropped silently.
class HabitFormSheet extends StatefulWidget {
  final List<HabitCategory> categories;
  final Habit? habit;

  const HabitFormSheet({required this.categories, this.habit, super.key});

  static Future<HabitDraft?> show(BuildContext context, {required List<HabitCategory> categories, Habit? habit}) =>
      showModalBottomSheet<HabitDraft>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        // Dragging would bypass the unsaved-changes check; the header has Cancel.
        enableDrag: false,
        backgroundColor: context.themeOf.scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => HabitFormSheet(categories: categories, habit: habit),
      );

  /// Quick picks; any other single emoji can be typed.
  static const suggestedIcons = ['📚', '🏃', '💧', '🧘', '✍️', '🎨', '🎸', '💻', '😴', '🍎', '🚶', '💰'];

  /// Limits of the `habit` table.
  static const maxTitleLength = 200;
  static const maxDescriptionLength = 2000;

  @override
  State<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<HabitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.habit?.title ?? '');
  late final _description = TextEditingController(text: widget.habit?.description ?? '');
  late final _customIcon = TextEditingController(
    text: HabitFormSheet.suggestedIcons.contains(widget.habit?.icon) ? '' : widget.habit?.icon ?? '',
  );
  late String _icon = widget.habit?.icon ?? HabitFormSheet.suggestedIcons.first;
  late String? _categoryId = widget.habit?.categoryId ?? widget.categories.firstOrNull?.id;
  late ScheduleType _scheduleType = widget.habit?.schedule.type ?? ScheduleType.daily;
  late int _weeklyTarget = widget.habit?.schedule.weeklyTarget ?? 3;
  late Set<int> _weekdays = {...?widget.habit?.schedule.weekdays};
  var _autovalidate = AutovalidateMode.disabled;
  var _showWeekdaysError = false;

  /// The schedule as chosen; null while weekdays are selected but none is ticked.
  HabitSchedule? get _schedule => switch (_scheduleType) {
        ScheduleType.daily => HabitSchedule.daily,
        ScheduleType.weeklyTarget => HabitSchedule.weeklyTarget(_weeklyTarget),
        ScheduleType.weekdays => _weekdays.isEmpty ? null : HabitSchedule.weekdays(_weekdays),
      };

  bool get _isEditing => widget.habit != null;

  bool get _isDirty {
    final habit = widget.habit;
    if (habit == null) {
      return _title.text.trim().isNotEmpty ||
          _description.text.trim().isNotEmpty ||
          _customIcon.text.isNotEmpty ||
          _scheduleType != ScheduleType.daily;
    }
    return _title.text.trim() != habit.title ||
        _description.text.trim() != (habit.description ?? '').trim() ||
        _icon != habit.icon ||
        _categoryId != habit.categoryId ||
        _schedule != habit.schedule;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _customIcon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final schedule = _schedule;
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _showWeekdaysError = schedule == null;
    });
    final categoryId = _categoryId;
    if (!_formKey.currentState!.validate() || categoryId == null || schedule == null) return;

    // Another schedule type counts streaks differently: ask before starting over.
    final typeChanged = _isEditing && schedule.type != widget.habit!.schedule.type;
    if (typeChanged && !await _confirmScheduleChange()) return;
    if (!mounted) return;
    Navigator.of(context).pop<HabitDraft>((
      title: _title.text.trim(),
      description: _description.text.trim(),
      icon: _icon,
      categoryId: categoryId,
      schedule: schedule,
      resetStreak: typeChanged,
    ));
  }

  Future<bool> _confirmScheduleChange() async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.themeOf.cardColor,
            title: Text(l10n.habits_schedule_change_title),
            content: Text(l10n.habits_schedule_change_message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.habits_schedule_change_confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _cancel() async {
    if (!_isDirty || await _confirmDiscard()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard() async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.themeOf.cardColor,
            title: Text(l10n.habits_discard_title),
            content: Text(l10n.habits_discard_message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.habits_keep_editing)),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.habits_discard),
              ),
            ],
          ),
        ) ??
        false;
  }

  String? _validateIcon(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null; // a quick pick is used
    return text.characters.length == 1 ? null : context.l10n.habits_icon_single;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final green = context.theme.commonColors.green100;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _isEditing ? l10n.habits_edit_title : l10n.habits_new_title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      PressableScale(
                        child: FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(backgroundColor: green, minimumSize: const Size(48, 40)),
                          child: Text(l10n.social_save),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.habits_icon_label, style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final icon in HabitFormSheet.suggestedIcons)
                              _IconChoice(
                                icon: icon,
                                selected: _icon == icon,
                                onTap: () => setState(() {
                                  _icon = icon;
                                  _customIcon.clear();
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customIcon,
                          decoration: InputDecoration(
                            labelText: l10n.habits_icon_custom,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: _validateIcon,
                          onChanged: (value) {
                            final text = value.trim();
                            setState(() => _icon = text.characters.length == 1 ? text : _icon);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _title,
                          autofocus: !_isEditing,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [LengthLimitingTextInputFormatter(HabitFormSheet.maxTitleLength)],
                          decoration:
                              InputDecoration(labelText: l10n.habits_name_label, border: const OutlineInputBorder()),
                          validator: (value) => (value ?? '').trim().isEmpty ? l10n.habits_name_required : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          minLines: 1,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [LengthLimitingTextInputFormatter(HabitFormSheet.maxDescriptionLength)],
                          decoration: InputDecoration(
                            labelText: l10n.habits_description_label,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.habits_category_label, style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        if (widget.categories.isEmpty)
                          const Center(child: CircularProgressIndicator.adaptive())
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final category in widget.categories)
                                ChoiceChip(
                                  avatar: Icon(getCategoryIcon(category.id), size: 18, color: Colors.white),
                                  label: Text(category.name),
                                  selected: _categoryId == category.id,
                                  showCheckmark: false,
                                  selectedColor: hexToColor(category.color),
                                  backgroundColor: Colors.grey.shade700,
                                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  onSelected: (_) {
                                    if (_categoryId != category.id) AppHaptics.selection();
                                    setState(() => _categoryId = category.id);
                                  },
                                ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        _ScheduleSection(
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
                      ],
                    ),
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

/// Schedule type, its parameter and a summary.
class _ScheduleSection extends StatelessWidget {
  final ScheduleType type;
  final int weeklyTarget;
  final Set<int> weekdays;
  final bool showWeekdaysError;
  final String? summary;
  final ValueChanged<ScheduleType> onTypeChanged;
  final ValueChanged<int> onTargetChanged;
  final ValueChanged<int> onWeekdayToggled;

  const _ScheduleSection({
    required this.type,
    required this.weeklyTarget,
    required this.weekdays,
    required this.showWeekdaysError,
    required this.summary,
    required this.onTypeChanged,
    required this.onTargetChanged,
    required this.onWeekdayToggled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.themeOf;
    final green = context.theme.commonColors.green100;
    final error = theme.colorScheme.error;

    Widget typeChip(ScheduleType value, String label) => ChoiceChip(
          label: Text(label),
          selected: type == value,
          showCheckmark: false,
          selectedColor: green,
          labelStyle: TextStyle(color: type == value ? Colors.white : null, fontWeight: FontWeight.w600),
          side: BorderSide(color: type == value ? green : theme.dividerColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onSelected: (_) {
            if (type != value) AppHaptics.selection();
            onTypeChanged(value);
          },
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.habits_schedule_label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            typeChip(ScheduleType.daily, l10n.habits_schedule_option_daily),
            typeChip(ScheduleType.weeklyTarget, l10n.habits_schedule_option_weekly),
            typeChip(ScheduleType.weekdays, l10n.habits_schedule_option_weekdays),
          ],
        ),
        if (type == ScheduleType.weeklyTarget) ...[
          const SizedBox(height: 12),
          Text(l10n.habits_weekly_target_label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var count = 1; count <= 7; count++)
                _RoundToggle(
                  label: '$count',
                  semanticsLabel: l10n.habits_schedule_times_per_week(count),
                  selected: weeklyTarget == count,
                  onTap: () => onTargetChanged(count),
                ),
            ],
          ),
        ],
        if (type == ScheduleType.weekdays) ...[
          const SizedBox(height: 12),
          Text(l10n.habits_weekdays_label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                _RoundToggle(
                  label: l10n.weekdayShort(day),
                  selected: weekdays.contains(day),
                  onTap: () => onWeekdayToggled(day),
                ),
            ],
          ),
          if (showWeekdaysError)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(l10n.habits_weekdays_required, style: theme.textTheme.bodySmall?.copyWith(color: error)),
              ),
            ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_repeat, size: 16, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Expanded(child: Text(summary!, style: theme.textTheme.bodySmall)),
            ],
          ),
        ],
      ],
    );
  }
}

/// A round selectable chip for a number or a weekday.
class _RoundToggle extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  const _RoundToggle({required this.label, required this.selected, required this.onTap, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    final green = context.theme.commonColors.green100;
    final theme = context.themeOf;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? green : Colors.transparent,
            border: Border.all(color: selected ? green : theme.dividerColor),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final green = context.theme.commonColors.green100;
    return Semantics(
      button: true,
      selected: selected,
      label: icon,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (!selected) AppHaptics.selection();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? green.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(color: selected ? green : context.themeOf.dividerColor, width: selected ? 2 : 1),
          ),
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

Color hexToColor(String hexString) {
  // Удаляем возможный префикс '#'
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) {
    buffer.write('ff'); // Добавляем непрозрачность (alpha) по умолчанию
  }
  buffer.write(hexString.replaceFirst('#', ''));

  // Преобразуем в целое число и создаем Color
  return Color(int.parse(buffer.toString(), radix: 16));
}

IconData getCategoryIcon(String categoryId) {
  switch (categoryId) {
    case 'art':
      return Icons.brush; // Иконка творчества
    case 'education':
      return Icons.school; // Иконка обучения
    case 'health':
      return Icons.fitness_center; // Иконка здоровья
    case 'money':
      return Icons.attach_money; // Иконка финансов
    case 'selv-development':
      return Icons.self_improvement; // Саморазвитие
    case 'sport':
      return Icons.sports_soccer; // Иконка спорта
    case 'work':
      return Icons.work; // Иконка работы
    default:
      return Icons.category; // Иконка по умолчанию
  }
}
