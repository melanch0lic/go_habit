import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:go_habit/core/database/drift_database.dart';

/// Unit of a template's recommended daily target.
enum TargetUnit {
  pages,
  minutes,
  steps,
  glasses,
  hours;

  /// Unknown units (from a newer server) are ignored instead of failing.
  static TargetUnit? tryParse(String? value) => TargetUnit.values.where((unit) => unit.name == value).firstOrNull;
}

/// A catalog entry (`public.habit_template`). Each template has exactly one
/// persistent community, identified by the template id.
@immutable
class HabitTemplate {
  final String id;
  final String categoryId;

  /// Localized texts by language code; Russian is the fallback.
  final Map<String, String> title;
  final Map<String, String> description;
  final String icon;
  final int? targetValue;
  final TargetUnit? targetUnit;
  final int sortOrder;

  /// Retired templates remain visible to their members but cannot be joined.
  final bool isActive;

  const HabitTemplate({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.icon,
    this.targetValue,
    this.targetUnit,
    this.sortOrder = 0,
    this.isActive = true,
  });

  static const columns = 'id, category_id, title, description, icon, target_value, target_unit, sort_order, is_active';

  String titleFor(String languageCode) => _localized(title, languageCode);

  String descriptionFor(String languageCode) => _localized(description, languageCode);

  bool get hasTarget => targetValue != null && targetUnit != null;

  /// Whether [query] (already lower-cased) occurs in any language's title or description.
  bool matches(String query) =>
      query.isEmpty || [...title.values, ...description.values].any((text) => text.toLowerCase().contains(query));

  static String _localized(Map<String, String> texts, String languageCode) =>
      texts[languageCode] ?? texts['ru'] ?? texts.values.firstOrNull ?? '';

  factory HabitTemplate.fromJson(Map<String, dynamic> json) => HabitTemplate(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        title: _texts(json['title']),
        description: _texts(json['description']),
        icon: json['icon'] as String,
        targetValue: json['target_value'] as int?,
        targetUnit: TargetUnit.tryParse(json['target_unit'] as String?),
        sortOrder: json['sort_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  factory HabitTemplate.fromDriftModel(HabitTemplateEntry entry) => HabitTemplate(
        id: entry.id,
        categoryId: entry.categoryId,
        title: _texts(jsonDecode(entry.title)),
        description: _texts(jsonDecode(entry.description)),
        icon: entry.icon,
        targetValue: entry.targetValue,
        targetUnit: TargetUnit.tryParse(entry.targetUnit),
        sortOrder: entry.sortOrder,
        isActive: entry.isActive,
      );

  HabitTemplatesCompanion toCompanion() => HabitTemplatesCompanion.insert(
        id: id,
        categoryId: categoryId,
        title: jsonEncode(title),
        description: jsonEncode(description),
        icon: icon,
        targetValue: Value(targetValue),
        targetUnit: Value(targetUnit?.name),
        sortOrder: Value(sortOrder),
        isActive: Value(isActive),
      );

  static Map<String, String> _texts(Object? value) =>
      value is Map ? {for (final MapEntry(:key, :value) in value.entries) '$key': '$value'} : const {};

  @override
  bool operator ==(Object other) => other is HabitTemplate && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HabitTemplate($id)';
}
