import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/activity_entity.dart';
import '../../domain/entities/gps_point_entity.dart';
import '../../domain/repositories/run_repository.dart';
import '../datasources/run_remote_datasource.dart';
import '../models/gps_point_model.dart';

class RunRepositoryImpl implements RunRepository {
  final RunRemoteDataSource _dataSource;

  RunRepositoryImpl(this._dataSource);

  @override
  Future<ActivityEntity> saveActivity({
    required String userId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double distanceMeters,
    required int? avgPaceSecondsPerKm,
    required List<GpsPointEntity> points,
  }) async {
    final activity = await _dataSource.insertActivity(
      userId: userId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm,
    );

    final models = points
        .map((p) => GpsPointModel(
              latitude: p.latitude,
              longitude: p.longitude,
              altitude: p.altitude,
              recordedAt: p.recordedAt,
              sequence: p.sequence,
            ))
        .toList();

    await _dataSource.insertActivityPoints(activity.id, models);
    return activity;
  }

  @override
  Future<ActivityEntity> getActivity(String activityId) async {
    return _dataSource.getActivity(activityId);
  }

  @override
  Future<List<GpsPointEntity>> getActivityPoints(String activityId) async {
    return _dataSource.getActivityPoints(activityId);
  }
}

final runRepositoryProvider = Provider<RunRepository>((ref) {
  return RunRepositoryImpl(ref.watch(runRemoteDataSourceProvider));
});
