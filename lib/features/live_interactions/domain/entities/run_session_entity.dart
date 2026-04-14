class RunSessionEntity {
  final String id;
  final String userId;
  final String status; // 'active' | 'completed'
  final double distanceMeters;
  final int elapsedSeconds;
  final double? currentPaceSecondsPerKm;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime updatedAt;

  const RunSessionEntity({
    required this.id,
    required this.userId,
    required this.status,
    required this.distanceMeters,
    required this.elapsedSeconds,
    this.currentPaceSecondsPerKm,
    required this.startedAt,
    this.endedAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  String get formattedDistance {
    final km = distanceMeters / 1000;
    return km.toStringAsFixed(2);
  }

  String get formattedDuration {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (currentPaceSecondsPerKm == null || currentPaceSecondsPerKm! <= 0) {
      return '--:--';
    }
    final totalSeconds = currentPaceSecondsPerKm!.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  RunSessionEntity copyWith({
    String? status,
    double? distanceMeters,
    int? elapsedSeconds,
    double? currentPaceSecondsPerKm,
    DateTime? endedAt,
    DateTime? updatedAt,
  }) {
    return RunSessionEntity(
      id: id,
      userId: userId,
      status: status ?? this.status,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
