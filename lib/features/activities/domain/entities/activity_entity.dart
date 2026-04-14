/// Activity entity representing a user's running/walking activity
class ActivityEntity {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final int? avgPaceSecondsPerKm;
  final int? steps;
  final double? calories;
  final DateTime createdAt;

  const ActivityEntity({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    this.avgPaceSecondsPerKm,
    this.steps,
    this.calories,
    required this.createdAt,
  });

  /// Get distance in kilometers
  double get distanceKm => distanceMeters / 1000;

  /// Get formatted duration (HH:MM:SS or MM:SS)
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
  }

  /// Get formatted pace (MM:SS per km)
  String? get formattedPace {
    if (avgPaceSecondsPerKm == null) return null;
    final minutes = avgPaceSecondsPerKm! ~/ 60;
    final seconds = avgPaceSecondsPerKm! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ActivityEntity &&
        other.id == id &&
        other.userId == userId &&
        other.startedAt == startedAt &&
        other.endedAt == endedAt &&
        other.durationSeconds == durationSeconds &&
        other.distanceMeters == distanceMeters &&
        other.avgPaceSecondsPerKm == avgPaceSecondsPerKm &&
        other.steps == steps &&
        other.calories == calories &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        startedAt.hashCode ^
        endedAt.hashCode ^
        durationSeconds.hashCode ^
        distanceMeters.hashCode ^
        avgPaceSecondsPerKm.hashCode ^
        steps.hashCode ^
        calories.hashCode ^
        createdAt.hashCode;
  }
}
