import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../models/run_session_model.dart';

class RunSessionRemoteDatasource {
  final SupabaseClient _client;

  RunSessionRemoteDatasource(this._client);

  Future<RunSessionModel> createSession(String userId) async {
    try {
      final response = await _client
          .from('run_sessions')
          .insert({
            'user_id': userId,
            'status': 'active',
            'distance_meters': 0,
            'elapsed_seconds': 0,
          })
          .select()
          .single();
      return RunSessionModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure('Impossible de créer la session: ${e.message}');
    }
  }

  Future<void> updateSession({
    required String sessionId,
    required double distanceMeters,
    required int elapsedSeconds,
    double? currentPaceSecondsPerKm,
  }) async {
    try {
      await _client.from('run_sessions').update({
        'distance_meters': distanceMeters,
        'elapsed_seconds': elapsedSeconds,
        'current_pace_seconds_per_km': currentPaceSecondsPerKm,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure('Impossible de mettre à jour la session: ${e.message}');
    }
  }

  Future<void> endSession(String sessionId) async {
    try {
      await _client.from('run_sessions').update({
        'status': 'completed',
        'ended_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure('Impossible de terminer la session: ${e.message}');
    }
  }

  Future<List<RunSessionModel>> getActiveFriendSessions() async {
    try {
      // Only fetch sessions updated within the last 4 hours to filter orphaned sessions
      final staleThreshold =
          DateTime.now().subtract(const Duration(hours: 4)).toIso8601String();
      final response = await _client
          .from('run_sessions')
          .select()
          .eq('status', 'active')
          .gte('updated_at', staleThreshold)
          .order('started_at', ascending: false);
      return (response as List)
          .map((e) => RunSessionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure('Impossible de charger les sessions: ${e.message}');
    }
  }

  Stream<RunSessionModel?> watchSession(String sessionId) {
    return _client
        .from('run_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return RunSessionModel.fromJson(rows.first);
        });
  }
}
