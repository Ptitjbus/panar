import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/activity_model.dart';
import '../models/gps_point_model.dart';

class RunRemoteDataSource {
  final SupabaseClient _client;

  RunRemoteDataSource(this._client);

  Future<ActivityModel> insertActivity({
    required String userId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double distanceMeters,
    required int? avgPaceSecondsPerKm,
  }) async {
    try {
      final response = await _client
          .from('activities')
          .insert({
            'user_id': userId,
            'started_at': startedAt.toIso8601String(),
            'ended_at': endedAt.toIso8601String(),
            'duration_seconds': durationSeconds,
            'distance_meters': distanceMeters,
            'avg_pace_seconds_per_km': avgPaceSecondsPerKm,
          })
          .select()
          .single();
      return ActivityModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    }
  }

  Future<void> insertActivityPoints(
    String activityId,
    List<GpsPointModel> points,
  ) async {
    if (points.isEmpty) return;
    try {
      await _client
          .from('activity_points')
          .insert(points.map((p) => p.toJson(activityId)).toList());
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    }
  }

  Future<ActivityModel> getActivity(String activityId) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();
      return ActivityModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    }
  }

  Future<List<GpsPointModel>> getActivityPoints(String activityId) async {
    try {
      final response = await _client
          .from('activity_points')
          .select()
          .eq('activity_id', activityId)
          .order('sequence');
      return (response as List)
          .map((json) => GpsPointModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    }
  }
}

final runRemoteDataSourceProvider = Provider<RunRemoteDataSource>((ref) {
  return RunRemoteDataSource(ref.watch(supabaseClientProvider));
});
