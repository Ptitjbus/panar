import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/duel_repository_impl.dart';
import '../../domain/entities/duel_entity.dart';
import '../../domain/entities/duel_ready_state_entity.dart';

class DuelState {
  final List<DuelEntity> myDuels;
  final List<DuelEntity> pendingInvites;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const DuelState({
    this.myDuels = const [],
    this.pendingInvites = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  DuelState copyWith({
    List<DuelEntity>? myDuels,
    List<DuelEntity>? pendingInvites,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return DuelState(
      myDuels: myDuels ?? this.myDuels,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class DuelNotifier extends StateNotifier<DuelState> {
  final Ref _ref;
  DuelNotifier(this._ref) : super(const DuelState()) {
    loadDuels();
  }

  Future<void> loadDuels() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(duelRepositoryProvider);
      final results = await Future.wait([
        repo.getMyDuels(),
        repo.getPendingInvites(),
      ]);
      state = state.copyWith(
        myDuels: results[0],
        pendingInvites: results[1],
        isLoading: false,
      );
    } on DatabaseFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Erreur de connexion');
    }
  }

  Future<DuelEntity?> createDuel({
    String? challengedId,
    required DuelTiming timing,
    int? deadlineHours,
    double? targetDistanceMeters,
    String? description,
  }) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      final duel = await repo.createDuel(
        challengedId: challengedId,
        timing: timing,
        deadlineHours: deadlineHours,
        targetDistanceMeters: targetDistanceMeters,
        description: description,
      );
      state = state.copyWith(successMessage: 'Défi envoyé !');
      await loadDuels();
      return duel;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la création du duel');
      return null;
    }
  }

  Future<bool> respondToDuel(String duelId, {required bool accept}) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      await repo.respondToDuel(duelId, accept: accept);
      state = state.copyWith(
        successMessage: accept ? 'Duel accepté !' : 'Duel refusé',
      );
      await loadDuels();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la réponse');
      return false;
    }
  }

  Future<void> linkActivityToDuel(
    String duelId,
    String activityId,
  ) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      final authState = _ref.read(authStateProvider);
      final userId = authState.value?.id;
      if (userId == null) return;

      final duel = state.myDuels.where((d) => d.id == duelId).firstOrNull;
      if (duel == null) return;

      final isChallenger = duel.challengerId == userId;
      await repo.linkActivity(duelId, activityId, isChallenger: isChallenger);

      await loadDuels();
      final updated = state.myDuels.where((d) => d.id == duelId).firstOrNull;
      if (updated != null &&
          updated.challengerActivityId != null &&
          updated.challengedActivityId != null) {
        await repo.resolveWinner(duelId);
        await loadDuels();
      }
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du lien activité');
    }
  }

  Future<bool> cancelDuel(String duelId) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      await repo.cancelDuel(duelId);
      state = state.copyWith(successMessage: 'Duel annulé');
      await loadDuels();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: "Erreur lors de l'annulation");
      return false;
    }
  }

  Future<void> setReady(String duelId) async {
    try {
      final repo = _ref.read(duelRepositoryProvider);
      await repo.setReady(duelId);
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur salle d\'attente');
    }
  }

  void clearMessages() => state = state.copyWith();
}

final duelNotifierProvider = StateNotifierProvider<DuelNotifier, DuelState>((ref) {
  ref.watch(authStateProvider); // rebuild when auth changes
  return DuelNotifier(ref);
});

final duelReadyStatesProvider =
    StreamProvider.family<List<DuelReadyStateEntity>, String>((ref, duelId) {
  final repo = ref.watch(duelRepositoryProvider);
  return repo.watchReadyStates(duelId);
});
