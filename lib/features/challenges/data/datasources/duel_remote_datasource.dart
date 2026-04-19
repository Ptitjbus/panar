import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/duel_model.dart';
import '../../domain/entities/duel_ready_state_entity.dart';

class DuelRemoteDataSource {
  final SupabaseClient _client;
  DuelRemoteDataSource(this._client);

  static const _profileSelect = '''
    *,
    challenger:profiles!duels_challenger_id_fkey(*),
    challenged:profiles!duels_challenged_id_fkey(*)
  ''';

  Future<List<DuelModel>> getDuels(String userId) async {
    try {
      final response = await _client
          .from('duels')
          .select(_profileSelect)
          .or('challenger_id.eq.$userId,challenged_id.eq.$userId')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));
      return (response as List)
          .map((j) => DuelModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get duels: $e');
    }
  }

  Future<DuelModel> createDuel({
    required String challengerId,
    required String challengedId,
    required String timing,
    int? deadlineHours,
    double? targetDistanceMeters,
    String? description,
  }) async {
    try {
      final response = await _client
          .from('duels')
          .insert({
            'challenger_id': challengerId,
            'challenged_id': challengedId,
            'timing': timing,
            if (deadlineHours != null) 'deadline_hours': deadlineHours,
            if (targetDistanceMeters != null) 'target_distance_meters': targetDistanceMeters,
            if (description != null) 'description': description,
          })
          .select(_profileSelect)
          .single()
          .timeout(const Duration(seconds: 10));
      return DuelModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to create duel: $e');
    }
  }

  Future<void> updateDuelStatus(String duelId, String status) async {
    try {
      await _client
          .from('duels')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update duel: $e');
    }
  }

  Future<void> linkActivity(
    String duelId,
    String activityId, {
    required bool isChallenger,
  }) async {
    try {
      final column = isChallenger ? 'challenger_activity_id' : 'challenged_activity_id';
      await _client
          .from('duels')
          .update({column: activityId, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to link activity: $e');
    }
  }

  Future<DuelModel> getDuel(String duelId) async {
    try {
      final response = await _client
          .from('duels')
          .select(_profileSelect)
          .eq('id', duelId)
          .single()
          .timeout(const Duration(seconds: 10));
      return DuelModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get duel: $e');
    }
  }

  Future<double> getActivityDistance(String activityId) async {
    try {
      final row = await _client
          .from('activities')
          .select('distance_meters')
          .eq('id', activityId)
          .single()
          .timeout(const Duration(seconds: 10));
      return (row['distance_meters'] as num).toDouble();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get activity distance: $e');
    }
  }

  Future<void> resolveWinner(String duelId, String winnerId) async {
    try {
      await _client
          .from('duels')
          .update({
            'winner_id': winnerId,
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to resolve winner: $e');
    }
  }

  Future<void> cancelDuel(String duelId, String cancelledById) async {
    try {
      await _client
          .from('duels')
          .update({
            'status': 'cancelled',
            'cancelled_by_id': cancelledById,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', duelId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to cancel duel: $e');
    }
  }

  Future<void> setReady(String duelId, String userId) async {
    try {
      await _client
          .from('duel_ready_states')
          .upsert(
            {'duel_id': duelId, 'user_id': userId, 'ready_at': DateTime.now().toIso8601String()},
            onConflict: 'duel_id,user_id',
          )
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to set ready: $e');
    }
  }

  Stream<List<DuelReadyStateEntity>> watchReadyStates(String duelId) {
    return _client
        .from('duel_ready_states')
        .stream(primaryKey: ['id'])
        .eq('duel_id', duelId)
        .map((rows) => rows
            .map((r) => DuelReadyStateEntity.fromJson(r))
            .toList());
  }
}

final duelRemoteDataSourceProvider = Provider<DuelRemoteDataSource>((ref) {
  return DuelRemoteDataSource(ref.watch(supabaseClientProvider));
});
