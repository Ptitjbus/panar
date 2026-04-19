import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../activities/data/repositories/activity_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../challenges/data/repositories/duel_repository_impl.dart';
import '../../../challenges/data/repositories/group_challenge_repository_impl.dart';
import '../../../challenges/domain/entities/duel_entity.dart';
import '../../../challenges/domain/entities/group_challenge_entity.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/repositories/avatar_repository_impl.dart';
import '../../domain/entities/avatar_entity.dart';
import '../../domain/entities/avatar_mood.dart';

/// Provider for user avatar based on current user ID
/// Automatically creates an avatar if the user doesn't have one
final userAvatarProvider = FutureProvider<AvatarEntity?>((ref) async {
  // Use watch(authStateProvider.future) to wait for the first data value
  // This will naturally suspend this provider while authState is loading
  final user = await ref.watch(authStateProvider.future);

  if (user == null) return null;

  final avatarRepository = ref.watch(avatarRepositoryProvider);

  // Try to get existing avatar
  final existingAvatar = await avatarRepository.getAvatar(user.id);

  if (existingAvatar != null) {
    return existingAvatar;
  }

  // Avatar doesn't exist, create one
  try {
    // Get user profile to use username as display name
    final profile = await ref.read(userProfileProvider.future);
    final displayName = profile?.username;

    // Create new avatar
    final newAvatar = await avatarRepository.createAvatar(user.id, displayName);
    return newAvatar;
  } catch (e) {
    // If creation fails, return null
    return null;
  }
});

/// Provider for friends' avatars
final friendsAvatarsProvider = FutureProvider<List<AvatarEntity>>((ref) async {
  final friends = ref.watch(friendsNotifierProvider.select((s) => s.friends));

  final authState = await ref.watch(authStateProvider.future);
  final currentUserId = authState?.id;

  if (currentUserId == null || friends.isEmpty) {
    return [];
  }

  final friendIds = friends
      .map((f) => f.getOtherUserId(currentUserId))
      .toList();

  final avatarRepository = ref.watch(avatarRepositoryProvider);
  return await avatarRepository.getAvatars(friendIds);
});

class AvatarCustomizationState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const AvatarCustomizationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  AvatarCustomizationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return AvatarCustomizationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class AvatarCustomizationNotifier extends StateNotifier<AvatarCustomizationState> {
  final Ref _ref;

  AvatarCustomizationNotifier(this._ref)
      : super(const AvatarCustomizationState());

  Future<bool> updateAvatar({
    required String userId,
    String? displayName,
    String? colorHex,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final repo = _ref.read(avatarRepositoryProvider);
      await repo.updateAvatar(
        userId: userId,
        displayName: displayName,
        colorHex: colorHex,
      );
      _ref.invalidate(userAvatarProvider);
      _ref.invalidate(friendsAvatarsProvider);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Avatar mis à jour !',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de mettre à jour l’avatar',
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}

final avatarCustomizationNotifierProvider = StateNotifierProvider<
    AvatarCustomizationNotifier, AvatarCustomizationState>((ref) {
  return AvatarCustomizationNotifier(ref);
});

final userAvatarMoodProvider = FutureProvider<AvatarMood>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return AvatarMood.neutral;

  try {
    final activityRepo = ref.watch(activityRepositoryProvider);
    final activities = await activityRepo.getUserActivities(user.id, limit: 10);

    if (activities.isEmpty) {
      return AvatarMood.crying;
    }

    final now = DateTime.now();
    final lastRunAt = activities.first.startedAt;
    final idleDuration = now.difference(lastRunAt);

    final duelRepo = ref.watch(duelRepositoryProvider);
    final duels = await duelRepo.getMyDuels();
    final hasRecentDuelWin = duels.any(
      (d) =>
          d.status == DuelStatus.completed &&
          d.winnerId == user.id &&
          now.difference(d.updatedAt).inDays <= 3,
    );

    final groupRepo = ref.watch(groupChallengeRepositoryProvider);
    final groupChallenges = await groupRepo.getMyChallenges();
    final hasRecentGroupCompletion = groupChallenges.any(
      (c) =>
          c.status == GroupChallengeStatus.completed &&
          c.endsAt != null &&
          now.difference(c.endsAt!).inDays <= 3,
    );

    if (hasRecentDuelWin || hasRecentGroupCompletion) {
      return AvatarMood.excited;
    }

    if (idleDuration.inDays >= 5) {
      return AvatarMood.crying;
    }
    if (idleDuration.inDays >= 2) {
      return AvatarMood.tired;
    }
    if (idleDuration.inHours <= 24) {
      return AvatarMood.happy;
    }
    return AvatarMood.neutral;
  } catch (_) {
    return AvatarMood.neutral;
  }
});
