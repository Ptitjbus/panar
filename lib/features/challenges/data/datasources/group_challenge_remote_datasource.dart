import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/group_challenge_model.dart';

class GroupChallengeRemoteDataSource {
  final SupabaseClient _client;
  GroupChallengeRemoteDataSource(this._client);

  static const _participantSelect = '''
    *,
    participants:group_challenge_participants(
      *,
      profile:profiles(*)
    )
  ''';

  Future<List<GroupChallengeModel>> getChallenges(String userId) async {
    try {
      final response = await _client
          .from('group_challenges')
          .select(_participantSelect)
          .eq('creator_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));
      return (response as List)
          .map((j) => GroupChallengeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get group challenges: $e');
    }
  }

  Future<List<GroupChallengeModel>> getChallengesForParticipant(
      String userId) async {
    try {
      final participantRows = await _client
          .from('group_challenge_participants')
          .select('challenge_id')
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));

      final ids = (participantRows as List)
          .map((r) => r['challenge_id'] as String)
          .toList();

      if (ids.isEmpty) return [];

      final response = await _client
          .from('group_challenges')
          .select(_participantSelect)
          .inFilter('id', ids)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map((j) => GroupChallengeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get participant challenges: $e');
    }
  }

  Future<GroupChallengeModel> createChallenge({
    required String creatorId,
    required String title,
    required int durationDays,
    required List<String> friendIds,
  }) async {
    try {
      final gcRow = await _client
          .from('group_challenges')
          .insert({
            'creator_id': creatorId,
            'title': title,
            'duration_days': durationDays,
          })
          .select('id')
          .single()
          .timeout(const Duration(seconds: 10));

      final challengeId = gcRow['id'] as String;

      await _client
          .from('group_challenge_participants')
          .insert(
            friendIds
                .map((id) => {'challenge_id': challengeId, 'user_id': id})
                .toList(),
          )
          .timeout(const Duration(seconds: 10));

      return getChallenge(challengeId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to create group challenge: $e');
    }
  }

  Future<GroupChallengeModel> getChallenge(String challengeId) async {
    try {
      final response = await _client
          .from('group_challenges')
          .select(_participantSelect)
          .eq('id', challengeId)
          .single()
          .timeout(const Duration(seconds: 10));
      return GroupChallengeModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get group challenge: $e');
    }
  }

  Future<void> updateParticipantStatus(
    String challengeId,
    String userId,
    String status,
  ) async {
    try {
      final update = <String, dynamic>{'status': status};
      if (status == 'accepted') {
        update['joined_at'] = DateTime.now().toIso8601String();
      }

      await _client
          .from('group_challenge_participants')
          .update(update)
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update participant status: $e');
    }
  }

  Future<void> activateChallenge(String challengeId, int durationDays) async {
    try {
      final now = DateTime.now();
      await _client
          .from('group_challenges')
          .update({
            'status': 'active',
            'starts_at': now.toIso8601String(),
            'ends_at': now.add(Duration(days: durationDays)).toIso8601String(),
          })
          .eq('id', challengeId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to activate challenge: $e');
    }
  }

  Future<void> incrementParticipantDistance(
    String challengeId,
    String userId,
    double additionalMeters,
  ) async {
    try {
      final row = await _client
          .from('group_challenge_participants')
          .select('total_distance_meters')
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .single()
          .timeout(const Duration(seconds: 10));
      final current = (row['total_distance_meters'] as num).toDouble();
      await _client
          .from('group_challenge_participants')
          .update({'total_distance_meters': current + additionalMeters})
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to increment distance: $e');
    }
  }
}

final groupChallengeRemoteDataSourceProvider =
    Provider<GroupChallengeRemoteDataSource>((ref) {
  return GroupChallengeRemoteDataSource(ref.watch(supabaseClientProvider));
});
