import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/duel_entity.dart';
import '../../domain/repositories/duel_repository.dart';
import '../datasources/duel_remote_datasource.dart';

class DuelRepositoryImpl implements DuelRepository {
  final DuelRemoteDataSource _ds;
  final String _userId;
  DuelRepositoryImpl(this._ds, this._userId);

  @override
  Future<List<DuelEntity>> getMyDuels() async {
    if (_userId.isEmpty) return [];
    final models = await _ds.getDuels(_userId);
    return models
        .where((d) => d.status != DuelStatus.pending || d.challengerId == _userId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<List<DuelEntity>> getPendingInvites() async {
    if (_userId.isEmpty) return [];
    final models = await _ds.getDuels(_userId);
    return models
        .where((d) => d.status == DuelStatus.pending && d.challengedId == _userId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<DuelEntity> createDuel({
    required String challengedId,
    required DuelTiming timing,
    int? deadlineHours,
  }) async {
    final model = await _ds.createDuel(
      challengerId: _userId,
      challengedId: challengedId,
      timing: timing.toJson(),
      deadlineHours: deadlineHours,
    );
    return model.toEntity();
  }

  @override
  Future<void> respondToDuel(String duelId, {required bool accept}) async {
    await _ds.updateDuelStatus(duelId, accept ? 'accepted' : 'rejected');
  }

  @override
  Future<void> linkActivity(
    String duelId,
    String activityId, {
    required bool isChallenger,
  }) async {
    await _ds.linkActivity(duelId, activityId, isChallenger: isChallenger);
  }

  @override
  Future<void> resolveWinner(String duelId) async {
    final duel = await _ds.getDuel(duelId);
    if (duel.challengerActivityId == null || duel.challengedActivityId == null) return;

    // Fetch both activity distances
    final challengerDist = await _ds.getActivityDistance(duel.challengerActivityId!);
    final challengedDist = await _ds.getActivityDistance(duel.challengedActivityId!);

    final winnerId = challengerDist >= challengedDist ? duel.challengerId : duel.challengedId;
    await _ds.resolveWinner(duelId, winnerId);
  }
}

final duelRepositoryProvider = Provider<DuelRepository>((ref) {
  final ds = ref.watch(duelRemoteDataSourceProvider);
  final userId = ref.watch(authStateProvider).value?.id ?? '';
  return DuelRepositoryImpl(ds, userId);
});
