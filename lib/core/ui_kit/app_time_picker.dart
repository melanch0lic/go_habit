import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_habit/core/theme/app_theme.dart';

/// Asks for a time of day in the platform's familiar way: the Material dial on
/// Android and elsewhere, the wheel in a bottom panel on iOS. Starts at [initial];
/// returns null when cancelled. The 12/24-hour format follows the system setting and
/// the locale.
Future<TimeOfDay?> showAppTimePicker(BuildContext context, {required TimeOfDay initial, String? title}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) return _cupertinoTimePicker(context, initial, title);
  return showTimePicker(
    context: context,
    initialTime: initial,
    helpText: title,
  );
}

Future<TimeOfDay?> _cupertinoTimePicker(BuildContext context, TimeOfDay initial, String? title) {
  final material = MaterialLocalizations.of(context);
  final use24h = MediaQuery.alwaysUse24HourFormatOf(context) ||
      material.timeOfDayFormat() != TimeOfDayFormat.h_colon_mm_space_a;
  var picked = initial;
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(material.cancelButtonLabel)),
                Expanded(
                  child: Text(
                    title ?? '',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context, picked), child: Text(material.okButtonLabel)),
              ],
            ),
          ),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(brightness: theme.brightness, primaryColor: theme.colorScheme.primary),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: use24h,
                initialDateTime: DateTime(2000, 1, 1, initial.hour, initial.minute),
                onDateTimeChanged: (value) => picked = TimeOfDay.fromDateTime(value),
              ),
            ),
          ),
        ],
      );
    },
  );
}
