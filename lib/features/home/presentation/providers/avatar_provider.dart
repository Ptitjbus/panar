import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/repositories/avatar_repository_impl.dart';
import '../../domain/entities/avatar_entity.dart';

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
