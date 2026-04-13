import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/run_repository_impl.dart';
import '../../domain/entities/activity_entity.dart';
import '../../domain/entities/gps_point_entity.dart';

typedef ActivityDetail = ({
  ActivityEntity activity,
  List<GpsPointEntity> points
});

final runActivityDetailProvider =
    FutureProvider.family<ActivityDetail, String>((ref, activityId) async {
  final repo = ref.watch(runRepositoryProvider);
  final activity = await repo.getActivity(activityId);
  final points = await repo.getActivityPoints(activityId);
  return (activity: activity, points: points);
});
