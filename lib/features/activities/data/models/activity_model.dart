import '../../domain/entities/activity_entity.dart';

/// Data model for Activity with JSON serialization
class ActivityModel extends ActivityEntity {
  const ActivityModel({
    required super.id,
    required super.userId,
    required super.startedAt,
    required super.endedAt,
    required super.durationSeconds,
    required super.distanceMeters,
    super.avgPaceSecondsPerKm,
    super.steps,
    super.calories,
    required super.createdAt,
  });

  /// Create ActivityModel from JSON (Supabase response)
  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      durationSeconds: json['duration_seconds'] as int,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      avgPaceSecondsPerKm: json['avg_pace_seconds_per_km'] as int?,
      steps: json['steps'] as int?,
      calories: json['calories'] != null
          ? (json['calories'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert ActivityModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'avg_pace_seconds_per_km': avgPaceSecondsPerKm,
      'steps': steps,
      'calories': calories,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
