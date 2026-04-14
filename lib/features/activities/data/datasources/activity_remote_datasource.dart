import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/activity_model.dart';

/// Remote data source for activity operations using Supabase
class ActivityRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ActivityRemoteDataSource(this._supabaseClient);

  /// Get user activities by user ID, ordered by most recent first
  /// Optional limit parameter to restrict number of results
  Future<List<ActivityModel>> getUserActivities(
    String userId, {
    int? limit,
  }) async {
    try {
      var query = _supabaseClient
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return (response as List)
          .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get activities: $e');
    }
  }

  /// Get a specific activity by ID
  Future<ActivityModel> getActivity(String activityId) async {
    try {
      final response = await _supabaseClient
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();

      return ActivityModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get activity: $e');
    }
  }
}

/// Provider for ActivityRemoteDataSource
final activityRemoteDataSourceProvider = Provider<ActivityRemoteDataSource>((
  ref,
) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return ActivityRemoteDataSource(supabaseClient);
});
