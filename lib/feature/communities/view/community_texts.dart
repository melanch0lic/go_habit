import 'package:flutter/widgets.dart';
import 'package:go_habit/feature/communities/domain/models/community.dart';
import 'package:go_habit/feature/communities/domain/models/habit_template.dart';
import 'package:go_habit/l10n/app_localizations.dart';

extension CommunityFailureText on CommunityFailure {
  String message(AppLocalizations l10n) => switch (this) {
        CommunityFailure.offline => l10n.community_error_offline,
        CommunityFailure.network => l10n.community_error_network,
        CommunityFailure.habitNotSynced => l10n.community_error_not_synced,
        CommunityFailure.notAllowed => l10n.community_error_not_allowed,
        CommunityFailure.unauthorized => l10n.community_error_unauthorized,
        CommunityFailure.unknown => l10n.community_error_unknown,
      };
}

extension TargetUnitText on TargetUnit {
  String format(int value, AppLocalizations l10n) => switch (this) {
        TargetUnit.pages => l10n.unit_pages(value),
        TargetUnit.minutes => l10n.unit_minutes(value),
        TargetUnit.steps => l10n.unit_steps(value),
        TargetUnit.glasses => l10n.unit_glasses(value),
        TargetUnit.hours => l10n.unit_hours(value),
      };
}

extension HabitTemplateText on HabitTemplate {
  /// E.g. "20 страниц"; null without a recommended target.
  String? targetText(AppLocalizations l10n, {int? value}) {
    final unit = targetUnit;
    final amount = value ?? targetValue;
    return unit == null || amount == null ? null : unit.format(amount, l10n);
  }
}

/// The language used to pick a template's localized texts.
String languageCodeOf(BuildContext context) => Localizations.localeOf(context).languageCode;
