import '../entities/activity_entity.dart';

/// Repository interface for activity operations
abstract class ActivityRepository {
  /// Get user activities by user ID
  Future<List<ActivityEntity>> getUserActivities(String userId, {int? limit});

  /// Get a specific activity by ID
  Future<ActivityEntity> getActivity(String activityId);
}
