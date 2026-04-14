import '../../domain/entities/run_session_entity.dart';

class RunSessionModel extends RunSessionEntity {
  const RunSessionModel({
    required super.id,
    required super.userId,
    required super.status,
    required super.distanceMeters,
    required super.elapsedSeconds,
    super.currentPaceSecondsPerKm,
    required super.startedAt,
    super.endedAt,
    required super.updatedAt,
  });

  factory RunSessionModel.fromJson(Map<String, dynamic> json) {
    return RunSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      elapsedSeconds: json['elapsed_seconds'] as int,
      currentPaceSecondsPerKm:
          (json['current_pace_seconds_per_km'] as num?)?.toDouble(),
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
      'distance_meters': distanceMeters,
      'elapsed_seconds': elapsedSeconds,
      'current_pace_seconds_per_km': currentPaceSecondsPerKm,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
