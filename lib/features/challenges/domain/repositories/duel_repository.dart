import '../entities/duel_entity.dart';

abstract class DuelRepository {
  Future<List<DuelEntity>> getMyDuels();
  Future<List<DuelEntity>> getPendingInvites();
  Future<DuelEntity> createDuel({
    String? challengedId,
    required DuelTiming timing,
    int? deadlineHours,
    double? targetDistanceMeters,
    String? description,
  });
  Future<void> respondToDuel(String duelId, {required bool accept});
  Future<void> linkActivity(String duelId, String activityId, {required bool isChallenger});
  Future<void> resolveWinner(String duelId);
  Future<void> cancelDuel(String duelId);
}
