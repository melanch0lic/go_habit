import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_habit/core/extension/locale_extension.dart';
import 'package:go_habit/core/extension/theme_extension.dart';
import 'package:go_habit/core/theme/app_theme.dart';
import 'package:go_habit/core/ui_kit/app_choice_chip.dart';
import 'package:go_habit/core/ui_kit/app_haptics.dart';
import 'package:go_habit/core/ui_kit/pressable_scale.dart';
import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:go_habit/feature/habits/data/models/habit.dart';
import 'package:go_habit/feature/habits/domain/habit_schedule.dart';
import 'package:go_habit/feature/habits/view/components/habit_reminder_section.dart';
import 'package:go_habit/feature/habits/view/components/habit_schedule_section.dart';
import 'package:go_habit/feature/habits/view/habit_texts.dart';
import 'package:go_habit/feature/notifications/domain/models/reminder_settings.dart';

/// What the form produced; the caller turns it into AddHabit or UpdateHabit.
/// `resetStreak` is true only when the user confirmed a change of schedule type.
typedef HabitDraft = ({
  String title,
  String description,
  String icon,
  String categoryId,
  HabitSchedule schedule,
  bool resetStreak,
  // The reminder on this device; null when none was ever set up.
  ReminderDraft? reminder,
});

/// Form for a new habit, or for editing [habit]. Pops with a [HabitDraft] on save and
/// with nothing on cancel; unsaved changes are never dropped silently.
class HabitFormSheet extends StatefulWidget {
  final List<HabitCategory> categories;
  final Habit? habit;

  /// The habit's current reminder on this device, if any.
  final ReminderDraft? reminder;

  const HabitFormSheet({required this.categories, this.habit, this.reminder, super.key});

  /// A standard modal bottom sheet holding a draggable sheet: it slides up, can be
  /// dragged (or flung) down to close, closes on a tap outside, stays below the status
  /// bar and above the keyboard. Unsaved changes are never dropped silently: closing a
  /// changed form in any of these ways asks first.
  static Future<HabitDraft?> show(
    BuildContext context, {
    required List<HabitCategory> categories,
    Habit? habit,
    ReminderDraft? reminder,
  }) =>
      showModalBottomSheet<HabitDraft>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        // The sheet's own drag would pop without the unsaved-changes check; the
        // draggable sheet inside handles dragging instead.
        enableDrag: false,
        backgroundColor: context.themeOf.scaffoldBackgroundColor,
        // The pinned header must not paint over the rounded top corners.
        clipBehavior: Clip.antiAlias,
        builder: (_) => HabitFormSheet(categories: categories, habit: habit, reminder: reminder),
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

  /// Sections a failed save scrolls to, so the reason is never off screen.
  final _titleKey = GlobalKey();
  final _iconKey = GlobalKey();
  final _scheduleKey = GlobalKey();
  final _reminderKey = GlobalKey();

  late bool _reminderOn = widget.reminder?.enabled ?? false;
  late TimeOfDay _reminderTime = widget.reminder?.time ?? const TimeOfDay(hour: 9, minute: 0);

  /// The reminder's own days. Taken from the schedule when a reminder is first turned
  /// on, then independent: later schedule changes never overwrite them.
  late Set<int> _reminderDays = {...?widget.reminder?.weekdays};
  var _showReminderDaysError = false;

  var _iconPickerOpen = false;
  final _sheet = DraggableScrollableController();
  var _closingByDrag = false;

  static const _sheetSize = 0.92;
  static const _sheetMinSize = 0.4;

  /// Days a new reminder starts with: the schedule's days; none for a weekly target,
  /// which has no fixed days.
  Set<int> get _defaultReminderDays => switch (_scheduleType) {
        ScheduleType.daily => {...HabitReminder.allDays},
        ScheduleType.weekdays => {..._weekdays},
        ScheduleType.weeklyTarget => <int>{},
      };

  Set<int> get _effectiveReminderDays => _reminderDays;

  /// The reminder as edited; null when there was none and it stays off.
  ReminderDraft? get _reminder => !_reminderOn && widget.reminder == null
      ? null
      : ReminderDraft(enabled: _reminderOn, time: _reminderTime, weekdays: _effectiveReminderDays);

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
          _scheduleType != ScheduleType.daily ||
          _reminderOn;
    }
    return _title.text.trim() != habit.title ||
        _description.text.trim() != (habit.description ?? '').trim() ||
        _icon != habit.icon ||
        _categoryId != habit.categoryId ||
        _schedule != habit.schedule ||
        _reminderChanged;
  }

  bool get _reminderChanged {
    final initial = widget.reminder;
    if (initial == null) return _reminderOn;
    final current = _reminder;
    // A switched-off reminder keeps its time and days; only on/off matters then.
    return current?.enabled != initial.enabled || (_reminderOn && current != initial);
  }

  @override
  void dispose() {
    _sheet.dispose();
    _title.dispose();
    _description.dispose();
    _customIcon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final schedule = _schedule;
    final reminderDaysMissing = _reminderOn && _effectiveReminderDays.isEmpty;
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _showWeekdaysError = schedule == null;
      _showReminderDaysError = reminderDaysMissing;
    });
    final categoryId = _categoryId;
    final fieldsValid = _formKey.currentState!.validate();
    final iconInvalid = _validateIcon(_customIcon.text) != null;
    if (iconInvalid) setState(() => _iconPickerOpen = true);
    if (!fieldsValid || categoryId == null || schedule == null || reminderDaysMissing) {
      _revealProblem(
        iconInvalid
            ? _iconKey
            : !fieldsValid
                ? _titleKey
                : schedule == null
                    ? _scheduleKey
                    : _reminderKey,
      );
      return;
    }

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
      reminder: _reminder,
    ));
  }

  /// Scrolls the section with the first problem into view once its error is shown;
  /// does nothing if it is already visible.
  void _revealProblem(GlobalKey section) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = section.currentContext;
      if (target == null || !target.mounted) return;
      target.findRenderObject()?.showOnScreen(
            duration: MediaQuery.disableAnimationsOf(target) ? Duration.zero : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
    });
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

  /// The sheet was dragged down to its smallest size: close it, asking first if
  /// something changed; keeping the changes brings the sheet back.
  bool _onSheetResized(DraggableScrollableNotification notification) {
    if (_closingByDrag || notification.extent > notification.minExtent + 0.01) return false;
    _closingByDrag = true;
    unawaited(() async {
      if (!_isDirty || await _confirmDiscard()) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (mounted && _sheet.isAttached) {
        await _sheet.animateTo(
          _sheetSize,
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      _closingByDrag = false;
    }());
    return false;
  }

  void _setReminderOn(bool value) => setState(() {
        _reminderOn = value;
        // First time on: start from the schedule's days (none for a weekly target).
        if (value && _reminderDays.isEmpty) _reminderDays = _defaultReminderDays;
        if (!value) _showReminderDaysError = false;
      });

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
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
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

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Semantics(
              header: true,
              child: Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
        );

    return PopScope(
      canPop: false,
      // A tap outside the sheet and the system back gesture end up here.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Padding(
        // The sheet sits above the keyboard, so the focused field stays visible.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: _onSheetResized,
          child: DraggableScrollableSheet(
            controller: _sheet,
            expand: false,
            initialChildSize: _sheetSize,
            minChildSize: _sheetMinSize,
            snap: true,
            snapSizes: const [_sheetSize],
            shouldCloseOnMinExtent: false,
            builder: (context, scrollController) => Form(
              key: _formKey,
              autovalidateMode: _autovalidate,
              child: CustomScrollView(
                // One scroll view: scrolling the form and dragging the sheet never fight.
                controller: scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  PinnedHeaderSliver(
                      child: _SheetHeader(
                          title: _isEditing ? l10n.habits_edit_title : l10n.habits_new_title,
                          onCancel: _cancel,
                          onSave: _save)),
                  SliverPadding(
                    // The top gap leaves room for a field's floating label, which sits on
                    // its border and would otherwise slip under the pinned header.
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.md,
                      AppSpacing.page,
                      AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                    // Built at once (not lazily): every field takes part in validation, and a
                    // failed save can scroll to any section.
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ----- The habit -----
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _IconButton(
                                key: _iconKey,
                                icon: _icon,
                                open: _iconPickerOpen,
                                onTap: () => setState(() => _iconPickerOpen = !_iconPickerOpen),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextFormField(
                                  key: _titleKey,
                                  controller: _title,
                                  textCapitalization: TextCapitalization.sentences,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [LengthLimitingTextInputFormatter(HabitFormSheet.maxTitleLength)],
                                  decoration: InputDecoration(labelText: l10n.habits_name_label),
                                  validator: (value) => (value ?? '').trim().isEmpty ? l10n.habits_name_required : null,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: !_iconPickerOpen
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.md),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
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
                                                  _iconPickerOpen = false;
                                                }),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        TextFormField(
                                          controller: _customIcon,
                                          decoration:
                                              InputDecoration(labelText: l10n.habits_icon_custom, isDense: true),
                                          validator: _validateIcon,
                                          onChanged: (value) {
                                            final text = value.trim();
                                            setState(() => _icon = text.characters.length == 1 ? text : _icon);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Padding(
                            // Under the name, next to the icon.
                            padding: const EdgeInsets.only(left: 56 + AppSpacing.md),
                            child: TextFormField(
                              controller: _description,
                              minLines: 1,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters: [LengthLimitingTextInputFormatter(HabitFormSheet.maxDescriptionLength)],
                              decoration: InputDecoration(labelText: l10n.habits_description_label),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          sectionTitle(l10n.habits_category_label),
                          if (widget.categories.isEmpty)
                            const Center(child: CircularProgressIndicator.adaptive())
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final category in widget.categories)
                                  AppChoiceChip(
                                    icon: getCategoryIcon(category.id),
                                    label: category.name,
                                    selected: _categoryId == category.id,
                                    color: hexToColor(category.color),
                                    onSelected: () => setState(() => _categoryId = category.id),
                                  ),
                              ],
                            ),
                          // ----- Schedule -----
                          const SizedBox(height: AppSpacing.lg),
                          HabitScheduleSection(
                            key: _scheduleKey,
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
                          // ----- Reminder -----
                          sectionTitle(l10n.habits_reminder_label),
                          HabitReminderSection(
                            key: _reminderKey,
                            enabled: _reminderOn,
                            time: _reminderTime,
                            weekdays: _effectiveReminderDays,
                            showDaysError: _showReminderDaysError,
                            scheduleType: _scheduleType,
                            onEnabledChanged: _setReminderOn,
                            onTimeChanged: (time) => setState(() => _reminderTime = time),
                            onDayToggled: (day) => setState(() {
                              _reminderDays = {..._reminderDays};
                              if (!_reminderDays.remove(day)) _reminderDays.add(day);
                              if (_reminderDays.isNotEmpty) _showReminderDaysError = false;
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
      ),
    );
  }
}

/// The pinned top of the sheet: the drag handle, Cancel, the title and Save. Always
/// visible, so the form can be saved or left from anywhere in it.
class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _SheetHeader({required this.title, required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            LayoutBuilder(
              builder: (context, constraints) {
                final titleText = Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                );
                final cancel = TextButton(onPressed: onCancel, child: Text(l10n.cancel));
                final save = PressableScale(
                  child: FilledButton(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(minimumSize: const Size(AppSizes.touchTarget, 40)),
                    child: Text(l10n.social_save),
                  ),
                );
                // With little room (narrow screen, large text) the title moves below the
                // buttons and Cancel becomes a close button, instead of squeezing text.
                final roomy = constraints.maxWidth >= 340 * MediaQuery.textScalerOf(context).scale(1);
                if (roomy) return Row(children: [cancel, Expanded(child: titleText), save]);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(tooltip: l10n.cancel, icon: const Icon(Icons.close), onPressed: onCancel),
                        const Spacer(),
                        Flexible(flex: 0, child: save),
                      ],
                    ),
                    titleText,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The habit's emoji next to its name; tapping it opens the icon choices.
class _IconButton extends StatelessWidget {
  final String icon;
  final bool open;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.open, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      expanded: open,
      label: '${context.l10n.habits_choose_icon}: $icon',
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          side: BorderSide(color: open ? scheme.primary : scheme.outlineVariant, width: open ? 2 : 1),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 56,
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
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
