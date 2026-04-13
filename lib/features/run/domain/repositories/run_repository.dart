import '../entities/activity_entity.dart';
import '../entities/gps_point_entity.dart';

abstract class RunRepository {
  Future<ActivityEntity> saveActivity({
    required String userId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double distanceMeters,
    required int? avgPaceSecondsPerKm,
    required List<GpsPointEntity> points,
  });

  Future<ActivityEntity> getActivity(String activityId);

  Future<List<GpsPointEntity>> getActivityPoints(String activityId);
}
