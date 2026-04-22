import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_challenge_entity.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';
import '../../domain/repositories/group_challenge_repository.dart';
import '../datasources/group_challenge_remote_datasource.dart';
import '../models/group_challenge_model.dart';

class GroupChallengeRepositoryImpl implements GroupChallengeRepository {
  final GroupChallengeRemoteDataSource _ds;
  final String _userId;
  GroupChallengeRepositoryImpl(this._ds, this._userId);

  @override
  Future<List<GroupChallengeEntity>> getMyChallenges() async {
    if (_userId.isEmpty) return [];
    final created = await _ds.getChallenges(_userId);
    final participating = await _ds.getChallengesForParticipant(_userId);

    final seen = <String>{};
    final all = <GroupChallengeEntity>[];
    for (final c in [...created, ...participating]) {
      if (seen.add(c.id)) all.add(c);
    }

    return all
        .where((c) {
          if (c.creatorId == _userId) return true;
          final myParticipation =
              c.participants.where((p) => p.userId == _userId).firstOrNull;
          return myParticipation?.status == ParticipantStatus.accepted;
        })
        .map((m) => (m as GroupChallengeModel).toEntity())
        .toList();
  }

  @override
  Future<List<GroupChallengeEntity>> getPendingInvites() async {
    if (_userId.isEmpty) return [];
    final participating = await _ds.getChallengesForParticipant(_userId);
    return participating
        .where((c) {
          final myParticipation =
              c.participants.where((p) => p.userId == _userId).firstOrNull;
          return myParticipation?.status == ParticipantStatus.invited;
        })
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<GroupChallengeEntity> createChallenge({
    required String title,
    required int durationDays,
    required List<String> friendIds,
    double? targetDistanceMeters,
    String? description,
  }) async {
    final model = await _ds.createChallenge(
      creatorId: _userId,
      title: title,
      durationDays: durationDays,
      friendIds: friendIds,
      targetDistanceMeters: targetDistanceMeters,
      description: description,
    );
    return model.toEntity();
  }

  @override
  Future<void> respondToChallenge(
    String challengeId, {
    required bool accept,
  }) async {
    await _ds.updateParticipantStatus(
      challengeId,
      _userId,
      accept ? 'accepted' : 'rejected',
    );
    if (accept) await _checkAndActivate(challengeId);
  }

  @override
  Future<void> forceStart(String challengeId) async {
    final challenge = await _ds.getChallenge(challengeId);
    await _ds.activateChallenge(challengeId, challenge.durationDays);
  }

  @override
  Future<void> incrementDistance(
    String challengeId,
    double additionalMeters,
  ) async {
    await _ds.incrementParticipantDistance(
        challengeId, _userId, additionalMeters);
  }

  @override
  Future<GroupChallengeEntity> getChallenge(String challengeId) async {
    final model = await _ds.getChallenge(challengeId);
    return model.toEntity();
  }

  Future<void> _checkAndActivate(String challengeId) async {
    final challenge = await _ds.getChallenge(challengeId);
    final allAccepted = challenge.participants
        .every((p) => p.status == ParticipantStatus.accepted);
    if (allAccepted) {
      await _ds.activateChallenge(challengeId, challenge.durationDays);
    }
  }

  @override
  Future<void> completeChallenge(String challengeId) async {
    await _ds.completeChallenge(challengeId);
  }

  @override
  Future<void> deleteChallenge(String challengeId) async {
    await _ds.deleteChallenge(challengeId);
  }

  @override
  Future<void> leaveChallenge(String challengeId) async {
    await _ds.leaveChallenge(challengeId, _userId);
  }
}

final groupChallengeRepositoryProvider = Provider<GroupChallengeRepository>((ref) {
  final ds = ref.watch(groupChallengeRemoteDataSourceProvider);
  final userId = ref.watch(authStateProvider).value?.id ?? '';
  return GroupChallengeRepositoryImpl(ds, userId);
});
