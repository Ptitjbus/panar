import '../entities/group_challenge_entity.dart';

abstract class GroupChallengeRepository {
  Future<List<GroupChallengeEntity>> getMyChallenges();
  Future<List<GroupChallengeEntity>> getPendingInvites();
  Future<GroupChallengeEntity> createChallenge({
    required String title,
    required int durationDays,
    required List<String> friendIds,
  });
  Future<void> respondToChallenge(String challengeId, {required bool accept});
  Future<void> forceStart(String challengeId);
  Future<void> incrementDistance(String challengeId, double additionalMeters);
  Future<GroupChallengeEntity> getChallenge(String challengeId);
}
