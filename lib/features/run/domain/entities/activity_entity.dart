class ActivityEntity {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final int? avgPaceSecondsPerKm;
  final DateTime createdAt;

  const ActivityEntity({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    this.avgPaceSecondsPerKm,
    required this.createdAt,
  });

  String get formattedDistance {
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(2)} km';
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (avgPaceSecondsPerKm == null || avgPaceSecondsPerKm! <= 0) return '--:-- /km';
    final minutes = avgPaceSecondsPerKm! ~/ 60;
    final seconds = avgPaceSecondsPerKm! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} /km';
  }
}
