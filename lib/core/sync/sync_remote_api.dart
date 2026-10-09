import 'package:flutter/foundation.dart';

/// Server side of synchronization. Implementations must map failures to [SyncException].
abstract interface class SyncRemoteApi {
  /// Inserts or updates habits by id. Idempotent.
  Future<void> upsertHabits(List<RemoteHabit> habits);

  /// Inserts or updates completions by (habit id, day). Idempotent.
  Future<void> upsertCompletions(List<RemoteCompletion> completions);

  /// Own habits (including tombstones) with `updated_at >= updatedSince`, oldest first.
  Future<List<RemoteHabit>> fetchHabits({required DateTime? updatedSince, required int limit});

  /// Own completions (including tombstones) with `updated_at >= updatedSince`, oldest first.
  Future<List<RemoteCompletion>> fetchCompletions({required DateTime? updatedSince, required int limit});
}

/// Wire representation of a `public.habit` row.
@immutable
class RemoteHabit {
  final String id;
  final String categoryId;
  final String title;
  final String? description;
  final String icon;
  final int steps;
  final bool isActive;
  final DateTime createdAt;

  /// Assigned by the server; null for rows that are being pushed.
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const RemoteHabit({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  static const columns =
      'id, category_id, title, description, icon, steps, is_active, created_at, updated_at, deleted_at';

  factory RemoteHabit.fromJson(Map<String, dynamic> json) => RemoteHabit(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String,
        steps: json['steps'] as int,
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        deletedAt: _parseNullable(json['deleted_at']),
      );

  /// `user_id` and `updated_at` are deliberately absent: the server assigns them.
  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'title': title,
        'description': description,
        'icon': icon,
        'steps': steps,
        'is_active': isActive,
        'created_at': createdAt.toUtc().toIso8601String(),
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };
}

/// Wire representation of a `public.habit_completion` row.
@immutable
class RemoteCompletion {
  final String id;
  final String habitId;

  /// `YYYY-MM-DD`.
  final String completedOn;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const RemoteCompletion({
    required this.id,
    required this.habitId,
    required this.completedOn,
    this.updatedAt,
    this.deletedAt,
  });

  static const columns = 'id, habit_id, completed_on, updated_at, deleted_at';

  factory RemoteCompletion.fromJson(Map<String, dynamic> json) => RemoteCompletion(
        id: json['id'] as String,
        habitId: json['habit_id'] as String,
        completedOn: json['completed_on'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        deletedAt: _parseNullable(json['deleted_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'habit_id': habitId,
        'completed_on': completedOn,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };
}

DateTime? _parseNullable(Object? value) => value == null ? null : DateTime.parse(value as String);

/// Failures of [SyncRemoteApi], classified by how the sync engine should react.
sealed class SyncException implements Exception {
  final String message;
  const SyncException(this.message);

  @override
  String toString() => 'SyncException($message)';
}

/// No connection or the request timed out. Retry later.
final class SyncNetworkException extends SyncException {
  const SyncNetworkException(super.message);
}

/// The session is missing or expired. Retry after the auth state changes.
final class SyncAuthException extends SyncException {
  const SyncAuthException(super.message);
}

/// Temporary server-side failure (5xx, overload, serialization conflict). Retry later.
final class SyncServerException extends SyncException {
  const SyncServerException(super.message);
}

/// The server permanently rejected the data (constraint or permission violation).
/// Retrying the same payload will fail again.
final class SyncRejectedException extends SyncException {
  const SyncRejectedException(super.message);
}
