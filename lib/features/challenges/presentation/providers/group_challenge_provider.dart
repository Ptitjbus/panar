import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../run/data/datasources/petons_datasource.dart';
import '../../data/repositories/group_challenge_repository_impl.dart';
import '../../domain/entities/group_challenge_entity.dart';

class GroupChallengeState {
  final List<GroupChallengeEntity> myChallenges;
  final List<GroupChallengeEntity> pendingInvites;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const GroupChallengeState({
    this.myChallenges = const [],
    this.pendingInvites = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  GroupChallengeState copyWith({
    List<GroupChallengeEntity>? myChallenges,
    List<GroupChallengeEntity>? pendingInvites,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return GroupChallengeState(
      myChallenges: myChallenges ?? this.myChallenges,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class GroupChallengeNotifier extends StateNotifier<GroupChallengeState> {
  final Ref _ref;
  GroupChallengeNotifier(this._ref) : super(const GroupChallengeState()) {
    loadChallenges();
  }

  Future<void> loadChallenges() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      final results = await Future.wait([
        repo.getMyChallenges(),
        repo.getPendingInvites(),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        myChallenges: results[0],
        pendingInvites: results[1],
        isLoading: false,
      );
    } on DatabaseFailure catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: 'Erreur de connexion');
    }
  }

  Future<GroupChallengeEntity?> createChallenge({
    required String title,
    required int durationDays,
    required List<String> friendIds,
    double? targetDistanceMeters,
    String? description,
  }) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      final challenge = await repo.createChallenge(
        title: title,
        durationDays: durationDays,
        friendIds: friendIds,
        targetDistanceMeters: targetDistanceMeters,
        description: description,
      );
      state = state.copyWith(successMessage: 'Défi créé !');
      await loadChallenges();
      return challenge;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la création');
      return null;
    }
  }

  Future<bool> respondToChallenge(String challengeId, {required bool accept}) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.respondToChallenge(challengeId, accept: accept);
      state = state.copyWith(
        successMessage: accept ? 'Défi accepté !' : 'Défi refusé',
      );
      await loadChallenges();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la réponse');
      return false;
    }
  }

  Future<void> forceStart(String challengeId) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.forceStart(challengeId);
      state = state.copyWith(successMessage: 'Défi lancé !');
      await loadChallenges();
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du lancement');
    }
  }

  Future<void> addRunDistance(String challengeId, double meters) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.incrementDistance(challengeId, meters);
      await loadChallenges();
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      // Silent — don't interrupt the run reward flow
    }
  }

  Future<bool> deleteChallenge(String challengeId) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.deleteChallenge(challengeId);
      state = state.copyWith(successMessage: 'Défi supprimé');
      await loadChallenges();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la suppression');
      return false;
    }
  }

  /// Marks the challenge completed in the DB and awards petons to the current user.
  Future<int> claimReward(String challengeId, int rewardAmount) async {
    int awarded = 0;
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.completeChallenge(challengeId);
      await loadChallenges();
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (_) {}

    try {
      final userId = _ref.read(authStateProvider).value?.id;
      if (userId != null) {
        awarded = await _ref
            .read(petonsDatasourceProvider)
            .awardPetons(userId, rewardAmount);
      }
    } catch (_) {}

    return awarded;
  }

  Future<bool> leaveChallenge(String challengeId) async {
    try {
      final repo = _ref.read(groupChallengeRepositoryProvider);
      await repo.leaveChallenge(challengeId);
      state = state.copyWith(successMessage: 'Défi quitté');
      await loadChallenges();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du retrait');
      return false;
    }
  }

  void clearMessages() => state = state.copyWith();
}

final groupChallengeNotifierProvider =
    StateNotifierProvider<GroupChallengeNotifier, GroupChallengeState>((ref) {
  ref.watch(authStateProvider);
  return GroupChallengeNotifier(ref);
});
