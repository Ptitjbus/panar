import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/activity_entity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/activity_remote_datasource.dart';

/// Implementation of ActivityRepository
class ActivityRepositoryImpl implements ActivityRepository {
  final ActivityRemoteDataSource _remoteDataSource;

  ActivityRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<ActivityEntity>> getUserActivities(
    String userId, {
    int? limit,
  }) async {
    return await _remoteDataSource.getUserActivities(userId, limit: limit);
  }

  @override
  Future<ActivityEntity> getActivity(String activityId) async {
    return await _remoteDataSource.getActivity(activityId);
  }
}

/// Provider for ActivityRepository
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final remoteDataSource = ref.watch(activityRemoteDataSourceProvider);
  return ActivityRepositoryImpl(remoteDataSource);
});
